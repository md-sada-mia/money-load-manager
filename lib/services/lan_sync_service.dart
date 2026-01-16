
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'sync_provider.dart';
import 'package:flutter/services.dart';
import '../models/sync_models.dart';

class LanSyncService implements SyncProvider {
  static const MethodChannel _msgChannel = MethodChannel('com.money_load_manager.wifi');

  // ... existing code ...

  Future<String?> _getLocalIpAddress() async {
    // Strategy 1: Socket Trick (Most reliable for active network)
    try {
      // Try Google DNS first (Internet)
      final socket = await Socket.connect('8.8.8.8', 53, timeout: const Duration(seconds: 1));
      final ip = socket.address.address;
      await socket.close();
      return ip;
    } catch (e) {
      _statusController.add('IP Strat 1 (Internet) failed: $e');
    }

    // Strategy 2: Network Interfaces (Fallback)
    try {
      final interfaces = await NetworkInterface.list();
      _statusController.add('Found ${interfaces.length} interfaces.');
      
      for (var interface in interfaces) {
        _statusController.add('Interface: ${interface.name}');
        for (var addr in interface.addresses) {
            _statusController.add(' - Addr: ${addr.address} (Loopback: ${addr.isLoopback}, LinkLocal: ${addr.isLinkLocal}, IPv4: ${addr.type == InternetAddressType.IPv4})');
            
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback && !addr.isLinkLocal) {
              return addr.address;
            }
        }
      }
    } catch (e) {
      _statusController.add('IP Strat 2 (Interfaces) failed: $e');
    }
    return null;
  }
  static const String _serviceType = '_moneyload._tcp';
  static const int _port = 4040;
  
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  ServerSocket? _serverSocket;
  Socket? _clientSocket;
  
  final _discoveredDevicesController = StreamController<SyncDevice>.broadcast();
  final _dataReceivedController = StreamController<SyncPacket>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  
  bool _isAdvertising = false;
  bool _isDiscovering = false;
  String? _currentIp;
  int get servicePort => _port;
  String? get serverIp => _currentIp;
  
  String? _customServiceName;
  
  // Callback to check if sync manager is still syncing
  bool Function()? _shouldContinueDiscovery;
  
  void setup(String name, {bool Function()? shouldContinueDiscovery}) {
    _customServiceName = name;
    _shouldContinueDiscovery = shouldContinueDiscovery;
  }


  @override
  Stream<SyncDevice> get discoveredDevices => _discoveredDevicesController.stream;

  @override
  Stream<SyncPacket> get dataReceived => _dataReceivedController.stream;

  @override
  Stream<String> get connectionStatus => _statusController.stream;

  @override
  Future<void> startAdvertising() async {
    if (_isAdvertising) return;
    
    try {
      // 0. Acquire Lock FIRST
      try {
        await _msgChannel.invokeMethod('acquireMulticastLock');
        debugPrint('LAN: Acquired MulticastLock (Advertising)');
      } catch (e) {
         debugPrint('LAN: Failed to acquire lock: $e');
      }

      // 1. Start TCP Server
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, _port);
      _serverSocket!.listen(_handleIncomingConnection);
      
      // 2. Get Local IP
      String? ip = await NetworkInfo().getWifiIP();
      _statusController.add('Wifi Info IP: $ip');
      
      if (ip == null || ip.isEmpty) {
         ip = await _getLocalIpAddress(); // Fallback
         _statusController.add('Fallback NetworkInterface IP: $ip');
      }
      
      _statusController.add('Advertising on LAN ($ip)');
      


  // ... (inside startAdvertising)
      // 3. Start mDNS Broadcast
      String name = _customServiceName ?? 'MoneyLoadMaster-${const Uuid().v4().substring(0, 4)}';
      
      BonsoirService service = BonsoirService(
        name: name,
        type: _serviceType,
        port: _port,
        attributes: {
          'type': 'master',
          'ip': ip ?? '0.0.0.0', // Explicitly share IP
        },
      );
      
      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.initialize();
      
      // Update IP immediately so UI shows it even if broadcast fails later
      _currentIp = ip;
      _isAdvertising = true;
      _statusController.add('Service Ready. IP: $ip'); // Explicit UI log

      await _broadcast!.start();
      
      debugPrint('LAN: Started advertising on port $_port with IP $ip');
    } catch (e) {
      _statusController.add('Error advertising: $e');
      debugPrint('LAN Error advertising: $e');
      // Even if advertising fails, keep IP visible if we found it
      if (_currentIp != null) _isAdvertising = true; 
    }
  }

  @override
  Future<void> stopAdvertising() async {
    await _broadcast?.stop();
    await _serverSocket?.close();
    
    try {
      await _msgChannel.invokeMethod('releaseMulticastLock');
    } catch (_) {}
    
    _isAdvertising = false;
    _currentIp = null;
    _statusController.add('Stopped advertising');
  }

  StreamSubscription? _discoverySubscription;

  @override
  Future<void> startDiscovery() async {
    // Force cleanup of any existing instance
    await stopDiscovery();
    
    // Acquire Lock for Discovery too
    try {
        await _msgChannel.invokeMethod('acquireMulticastLock');
    } catch (_) {}

    try {
      _discovery = BonsoirDiscovery(type: _serviceType);
      await _discovery!.initialize(); 
      
      // GUARD: If stopped while initializing
      if (_discovery == null) {
         debugPrint('LAN: Discovery stopped during initialization.');
         return;
      }

      debugPrint('LAN: BonsoirDiscovery initialized. Starting...');
      
      _discoverySubscription = _discovery!.eventStream!.listen((event) {
        // CRITICAL GUARDS: Stop processing if discovery is stopped or sync is not active
        if (_discovery == null) return;
        if (!_isDiscovering) return;
        if (_shouldContinueDiscovery != null && !_shouldContinueDiscovery!()) return;

        if (event is BonsoirDiscoveryServiceFoundEvent) {
          debugPrint('LAN: Service Found: ${event.service?.name}');
          event.service!.resolve(_discovery!.serviceResolver);
        } else if (event is BonsoirDiscoveryServiceResolvedEvent) {
          debugPrint('LAN: Service Resolved: ${event.service?.name}');
          final service = event.service as BonsoirService;
          final attributes = service.attributes ?? {};
          
          if (attributes['type'] == 'master') {
             String ip = attributes['ip'] ?? service.host ?? '';
             final device = SyncDevice(
               id: service.name,
               name: service.name,
               ipAddress: ip,
               servicePort: service.port,
             );
             _discoveredDevicesController.add(device);
          }
        } else if (event is BonsoirDiscoveryServiceLostEvent) {
          debugPrint('LAN: Service Lost: ${event.service?.name}');
        }
      });

      // GUARD: If stopped while setting up listener
      if (_discovery == null) {
         debugPrint('LAN: Discovery aborted (stopped before start).');
         await _discoverySubscription?.cancel();
         return;
      }

      await _discovery!.start();

      // FIX: Check if stopped during start()
      if (_discovery == null) {
          debugPrint('LAN: Discovery stopped during start(). Aborting flag update.');
          return;
      }

      _isDiscovering = true;
      _statusController.add('Scanning started. Waiting for broadcasts...');
      debugPrint('LAN: Discovery started successfully. Instance: ${_discovery.hashCode}');
    } catch (e) {
      _statusController.add('Error discovering: $e');
      debugPrint('LAN Discovery Error: $e');
      await stopDiscovery(); // Ensure cleanup on error
    }
  }

  @override
  Future<void> stopDiscovery() async {
    // Set flag FIRST to stop listener from processing new events
    _isDiscovering = false;
    
    // Capture and clear immediately to prevent race in startDiscovery
    final discoveryToStop = _discovery;
    _discovery = null;
    
    // Cancel subscription
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    
    // Stop Bonsoir discovery
    await discoveryToStop?.stop();
    
    // Release multicast lock
    try {
      await _msgChannel.invokeMethod('releaseMulticastLock');
    } catch (_) {}
    
    _statusController.add('Stopped scanning');
  }

  void _handleIncomingConnection(Socket socket) {
    final address = socket.remoteAddress.address;
    _statusController.add('LAN: Incoming connection from $address');
    debugPrint('LAN: Incoming connection from $address');

    socket.cast<List<int>>().transform(utf8.decoder).listen(
      (data) {
        try {
          // Note: transform(utf8.decoder) might split data into chunks if large.
          // For a robust implementation, we should buffer until newline or end.
          // For now, assuming standard JSON packet size fits or comes quickly.
          _statusController.add('LAN: Receiving data (${data.length} bytes)...');
          
          final jsonData = jsonDecode(data);
          final packet = SyncPacket.fromJson(jsonData);
          _dataReceivedController.add(packet);
          
          // Send ACK
          socket.write('ACK\n');
        } catch (e) {
          _statusController.add('LAN: Error parsing data: $e');
          debugPrint('LAN: Error parsing data: $e');
        }
      },
      onDone: () {
        _statusController.add('LAN: Connection closed by remote.');
        socket.close();
      },
      onError: (e) {
        _statusController.add('LAN: Connection error: $e');
        socket.close();
      },
    );
  }

  @override
  Future<bool> connect(String targetId) async {
    _statusController.add('Checking LAN connection to $targetId...');
    try {
      final socket = await Socket.connect(targetId, _port, timeout: const Duration(seconds: 3));
      socket.destroy(); // Close immediately, we just wanted to check connectivity
      _statusController.add('LAN Connection OK.');
      return true;
    } catch (e) {
      _statusController.add('LAN Connection check failed: $e');
      return false;
    }
  }

  @override
  Future<void> sendData(String targetId, SyncPacket packet) async {
     try {
       final socket = await Socket.connect(targetId, _port, timeout: const Duration(seconds: 5));
       _clientSocket = socket; // Keep reference to close later if needed
       
       final jsonStr = jsonEncode(packet.toJson());
       socket.write(jsonStr);
       await socket.flush();
       
       // Wait for ACK or just close? For now close.
       // Ideally we wait for ACK.
       await socket.close();
       _clientSocket = null;
       
       _statusController.add('Data sent to $targetId');
     } catch (e) {
       _statusController.add('Error sending: $e');
       rethrow; // Rethrow so SyncManager knows it failed
     }
  }

  @override
  Future<void> disconnect() async {
    await _clientSocket?.close();
  }
}
