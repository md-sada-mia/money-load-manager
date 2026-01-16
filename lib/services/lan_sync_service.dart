
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'sync_provider.dart';
import '../models/sync_models.dart';

class LanSyncService implements SyncProvider {
  // ... existing code ...

  Future<String?> _getLocalIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback && !addr.isLinkLocal) {
              return addr.address;
            }
        }
      }
    } catch (_) {}
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
      // 1. Start TCP Server
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, _port);
      _serverSocket!.listen(_handleIncomingConnection);
      
      // 2. Get Local IP
      String? ip = await NetworkInfo().getWifiIP();
      ip ??= await _getLocalIpAddress(); // Fallback
      
      _statusController.add('Advertising on LAN ($ip)');
      
      // 3. Start mDNS Broadcast
      BonsoirService service = BonsoirService(
        name: 'MoneyLoadMaster-${const Uuid().v4().substring(0, 4)}',
        type: _serviceType,
        port: _port,
        attributes: {
          'type': 'master',
          'ip': ip ?? '0.0.0.0', // Explicitly share IP
        },
      );
      
      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.start();
      
      _isAdvertising = true;
      debugPrint('LAN: Started advertising on port $_port with IP $ip');
    } catch (e) {
      _statusController.add('Error advertising: $e');
      debugPrint('LAN Error advertising: $e');
    }
  }

  @override
  Future<void> stopAdvertising() async {
    await _broadcast?.stop();
    await _serverSocket?.close();
    _isAdvertising = false;
    _statusController.add('Stopped advertising');
  }

  @override
  Future<void> startDiscovery() async {
    if (_isDiscovering) return;

    try {
      _discovery = BonsoirDiscovery(type: _serviceType);
      // await _discovery!.start(); // Moved to after listener setup
      
      _discovery!.eventStream!.listen((event) {
        // Workaround: Use dynamic check as class names vary by version
        final dynamicEvent = event as dynamic;
        final String typeStr = dynamicEvent.runtimeType.toString();
        
        if (typeStr.contains('Found') || typeStr.contains('Resolved')) {
          if (event.service == null) return;
          final service = event.service!;
          
          // Only proceed if we have enough info (Resolved)
          if (typeStr.contains('Resolved')) {
              debugPrint('LAN: Found service ${service.name} at ${service.toJson()}');
              
              String? ip;
              try {
                // Priority 1: Check attributes (inserted by us)
                if (service.attributes.containsKey('ip')) {
                   ip = service.attributes['ip']?.toString();
                }
                
                // Priority 2: Standard JSON
                if (ip == null || ip == '0.0.0.0') {
                   final json = service.toJson();
                   ip = json['host'] ?? json['ip']; 
                }
              } catch (_) {}

              final device = SyncDevice(
                id: service.name, 
                name: service.name,
                ipAddress: ip,
                servicePort: service.port,
              );
              _discoveredDevicesController.add(device);
          }
        }
      });

      await _discovery!.start();
      _isDiscovering = true;
      _statusController.add('Scanning LAN...');
      debugPrint('LAN: Started discovery service type $_serviceType');
    } catch (e) {
      _statusController.add('Error discovering: $e');
    }
  }

  @override
  Future<void> stopDiscovery() async {
    await _discovery?.stop();
    _isDiscovering = false;
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
    return true; 
  }

  @override
  Future<void> sendData(String targetId, SyncPacket packet) async {
     // For LAN, targetId needs to be IP address or look up from discovered list.
     // This is a simplification. We should maintain a map of id -> IP.
     
     // PROVISIONAL: We assume targetId IS the IP address for this basic implementation, 
     // or we implement a full ip-map.
     
     try {
       final socket = await Socket.connect(targetId, _port);
       final jsonStr = jsonEncode(packet.toJson());
       socket.write(jsonStr);
       await socket.flush();
       await socket.close();
       _statusController.add('Data sent to $targetId');
     } catch (e) {
       _statusController.add('Error sending: $e');
     }
  }

  @override
  Future<void> disconnect() async {
    await _clientSocket?.close();
  }
}
