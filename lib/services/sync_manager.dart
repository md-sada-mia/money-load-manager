
import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../models/sync_models.dart';
import 'lan_sync_service.dart';
import 'nearby_sync_service.dart';
import 'sync_provider.dart';
import 'sms_listener.dart';
import 'notification_service.dart';

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  final LanSyncService _lanService = LanSyncService();
  final NearbySyncService _nearbyService = NearbySyncService();
  LanSyncService get lanService => _lanService;

  SyncRole _role = SyncRole.worker;
  bool _isSyncing = false;
  String? _deviceId;
  String? _deviceName;

  final _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;
  
  // Persistent Logs
  final List<String> _logs = [];
  List<String> get logs => List.unmodifiable(_logs);


  int _sdkInt = 0;

  bool _useLan = false;
  bool _useNearby = false;

  bool get useLan => _useLan;
  bool get useNearby => _useNearby;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final roleIndex = prefs.getInt('sync_role') ?? 1; // Default Worker
    _role = SyncRole.values[roleIndex];
    _useLan = prefs.getBool('use_lan') ?? false;
    _useNearby = prefs.getBool('use_nearby') ?? false;
    
    // Get Device Info
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      _deviceId = androidInfo.id;
      _deviceName = androidInfo.model;
      _sdkInt = androidInfo.version.sdkInt;
    } else {
      _deviceId = 'unknown_device';
      _deviceName = 'Unknown Device';
    }

    // specific listeners for providers
    _lanService.dataReceived.listen(_handleDataReceived);
    _nearbyService.dataReceived.listen(_handleDataReceived);
    
    // Forward logs/status from services
    _lanService.connectionStatus.listen(_addLog);
    _nearbyService.connectionStatus.listen(_addLog);
    
    // Listen for Discovery (Worker Logic)
    _lanService.discoveredDevices.listen((device) => _handleDiscoveredDevice(device, _lanService));
    _nearbyService.discoveredDevices.listen((device) => _handleDiscoveredDevice(device, _nearbyService));
    
    // Listen for New Transactions (Worker Trigger)
    SmsListener.transactionStream.listen((_) {
      if (_role == SyncRole.worker && (_useLan || _useNearby)) {
        _addLog('New transaction detected. Triggering sync...');
        // Small delay to ensure DB write is complete
        Future.delayed(const Duration(seconds: 2), () {
           // We re-trigger discovery/sync flow
           startSync(); 
        });
      }
    });

    // Auto-start if enabled
    if (_useLan || _useNearby) {
      // Small delay to ensure everything is ready
      Future.delayed(const Duration(seconds: 2), () {
        startSync();
      });
    }
  }

  // Permission Logic
  Future<bool> _checkLanPermissions() async {
    // LAN needs Location (for Wi-Fi SSID access on some Android versions) 
    // and Notification (for Service)
     Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.notification,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  Future<bool> _checkNearbyPermissions() async {
    List<Permission> permissions = [
      Permission.location,
      Permission.notification,
    ];
    
     if (Platform.isAndroid) {
       if (_sdkInt >= 31) {
         permissions.addAll([
           Permission.bluetoothAdvertise,
           Permission.bluetoothConnect,
           Permission.bluetoothScan,
         ]);
       }
       if (_sdkInt >= 33) {
         permissions.add(Permission.nearbyWifiDevices); 
       }
    }
    
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    return statuses.values.every((s) => s.isGranted);
  }

  // ... (in setUseLan)
  Future<void> setUseLan(bool enable) async {
    if (enable) {
      if (!await _checkLanPermissions()) {
        _statusController.add('LAN Permissions Missing');
        return;
      }
    }
    _useLan = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_lan', enable);
    
    // Manage Background Service
    final service = FlutterBackgroundService();
    if (_useLan || _useNearby) {
      if (!await service.isRunning()) {
        await service.startService();
      }
    } else {
      service.invoke('stopService');
    }

    if (enable) {
      startSync();
    } else {
      // If disabling LAN, we might still be running Nearby
      // Simplest approach: stop everything and restart if needed
      await stopSync(); 
      if (_useNearby) startSync();
    }
  }

  Future<void> setUseNearby(bool enable) async {
    if (enable) {
      if (!await _checkNearbyPermissions()) {
        _statusController.add('Nearby Permissions Missing');
        return;
      }
    }
    _useNearby = enable;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_nearby', enable);
    
    // Manage Background Service
    final service = FlutterBackgroundService();
    if (_useLan || _useNearby) {
      if (!await service.isRunning()) {
        await service.startService();
      }
    } else {
      service.invoke('stopService');
    }
    
     if (enable) {
      startSync();
    } else {
      await stopSync();
      if (_useLan) startSync();
    }
  }

  Future<void> setRole(SyncRole role) async {
    _role = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sync_role', role.index);
    stopSync(); // Stop existing services if running
  }

  SyncRole get role => _role;

  Timer? _fallbackTimer;

  Future<void> startSync() async {
    if (_isSyncing) {
       _addLog('Sync Service restarting...');
       await stopSync();
    }
    
    if (!_useLan && !_useNearby) {
      _addLog('No sync method enabled.');
      return;
    }

    _isSyncing = true;
    _statusController.add('Starting Sync Service (${_role.name})...');

    if (_role == SyncRole.master) {
      // Master: Start Advertising based on selections
      if (_useLan) await _lanService.startAdvertising();
      if (_useNearby) await _nearbyService.startAdvertising();
       _addLog('Master Mode Active.');
    } else {
      // Worker: Hybrid Discovery Logic
      
      if (_useLan && !_useNearby) {
        // LAN Only
        _addLog('Scanning LAN...');
        await _lanService.startDiscovery();
      } else if (!_useLan && _useNearby) {
        // Nearby Only
        _addLog('Scanning Nearby...');
        await _nearbyService.startDiscovery();
      } else {
        // Both Enabled: Try LAN first, then Nearby
         _addLog('Scanning LAN (Hybrid)...');
        await _lanService.startDiscovery();
        
        _fallbackTimer?.cancel();
        _fallbackTimer = Timer(const Duration(seconds: 5), () async {
          if (_isSyncing) {
             _addLog('Starting Nearby Discovery (Hybrid)...');
             await _nearbyService.startDiscovery();
          }
        });
      }
    }
  }
  
  // Manual Connect for Worker
  Future<void> manualConnect(String ipAddress) async {
     if (_role != SyncRole.worker) {
       _addLog('Manual connect only available for Worker');
       return;
     }
     _addLog('Manual Connection requested to $ipAddress...');
     final device = SyncDevice(
       id: 'manual_lan', 
       name: 'Manual LAN Device', 
       ipAddress: ipAddress,
       servicePort: 4040,
     );
     // Use LanSyncService for manual IP
     _handleDiscoveredDevice(device, _lanService);
  }

  Future<void> stopSync() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    await _lanService.stopAdvertising();
    await _lanService.stopDiscovery();
    await _lanService.disconnect(); // Explicit disconnect

    await _nearbyService.stopAdvertising();
    await _nearbyService.stopDiscovery();
    await _nearbyService.disconnect(); // Explicit disconnect
    
    _isSyncing = false;
    _addLog('Sync Stopped');
  }

  // Helper to add logs internally and to stream
  void _addLog(String message) {
     final logMsg = "${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second} - $message";
     _logs.insert(0, logMsg);
     if (_logs.length > 100) _logs.removeLast();
     _statusController.add(message);
  }

  void clearLogs() {
    _logs.clear();
  }




  final _dataSyncedController = StreamController<void>.broadcast();
  Stream<void> get onDataSynced => _dataSyncedController.stream;

  // Handle incoming data (Master logic primarily)
  void _handleDataReceived(SyncPacket packet) async {
    _addLog('Receiving data from ${packet.deviceName}...');
    
    try {
      // 1. Verify Device Authorization
      bool isAuthorized = await DatabaseHelper.instance.isDeviceAuthorized(packet.deviceId);
      if (!isAuthorized) {
        // For now, AUTO-AUTHORIZE for demo/user ease, or prompt.
         _statusController.add('New device ${packet.deviceName}. Auto-authorizing...');
         await DatabaseHelper.instance.authorizeDevice(packet.deviceId, packet.deviceName);
      }

      // 2. Merge Transactions
      List<Transaction> transactions = packet.transactions.map((m) => Transaction.fromMap(m)).toList();
      int newCount = await DatabaseHelper.instance.mergeTransactions(transactions);
      
      // 3. Update Sync Log
      await DatabaseHelper.instance.updateSyncLog(packet.deviceId, packet.deviceName, DateTime.now().millisecondsSinceEpoch);
      
      _addLog('Synced: $newCount new transactions from ${packet.deviceName}');
      
      // Notify UI
      _dataSyncedController.add(null);
      
    } catch (e) {
      _addLog('Error processing sync data: $e');
      debugPrint('Sync Error: $e');
    }
  }

  // Guard to prevent parallel syncs
  bool _isBusySyncing = false;

  // Worker Logic: Found a Master, send data!
  void _handleDiscoveredDevice(SyncDevice device, SyncProvider provider) async {
    // If multiple discovery events come in, ignore if busy
    if (_isBusySyncing) return;

    // If we found a device via LAN, cancel the Nearby fallback
    if (provider is LanSyncService) {
       _statusController.add('LAN Master Found: ${device.name}. Cancelling Nearby Fallback.');
       _fallbackTimer?.cancel();
    }
    
      _addLog('Found Master: ${device.name}. Connecting...');
    
    await _syncDataWithMaster(device, provider);
  }

  Future<void> _syncDataWithMaster(SyncDevice target, SyncProvider provider) async {
    if (_isBusySyncing) return;
    _isBusySyncing = true;

    try {
      // 1. Fetch only UNSYNCED transactions
      final transactions = await DatabaseHelper.instance.getUnsyncedTransactions();
      
      if (transactions.isEmpty) {
         _statusController.add('No new transactions to sync.');
         _isBusySyncing = false;
         return;
      }
      
      _statusController.add('Sending ${transactions.length} new transactions...');

      // 2. Wrap in Packet
      final packet = SyncPacket(
        deviceId: _deviceId ?? 'unknown',
        deviceName: _deviceName ?? 'Unknown',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        transactions: transactions.map((t) => t.toMap()).toList(),
      );

      // 3. Determine Target Address
      String targetAddress;
      if (provider is LanSyncService) {
        if (target.ipAddress == null || target.ipAddress!.isEmpty) {
          _addLog('Error: Master IP not found for LAN sync.');
          _isBusySyncing = false;
          return;
        }
        targetAddress = target.ipAddress!;
        _addLog('Connecting to Master at $targetAddress...');
      } else {
        targetAddress = target.id;
        _addLog('Connecting to Master ID $targetAddress...');
      }

      // 4. Connect & Send with Retry Logic
      int maxRetries = 10;
      bool success = false;
      
      for (int i = 0; i < maxRetries; i++) {
        if (i > 0) {
           _statusController.add('Retry ${i + 1}/$maxRetries in 5s...');
           await Future.delayed(const Duration(seconds: 5)); // Wait before retry (Fixed 5s or could be exponential)
        }

        try {
            // Connect
            bool connected = await provider.connect(targetAddress).timeout(
              const Duration(seconds: 5),
              onTimeout: () => false,
            );
            
            if (!connected) {
               _statusController.add('Failed to connect ($targetAddress).');
               continue; // Try next retry
            }

            // Send
            await provider.sendData(targetAddress, packet).timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException('Send timed out');
              },
            );
            
            _statusController.add('Sync Complete!');
            success = true;
            
            // Mark as Synced
            final ids = transactions.where((t) => t.id != null).map((t) => t.id!).toList();
            if (ids.isNotEmpty) {
               await DatabaseHelper.instance.markTransactionsAsSynced(ids);
               _addLog('Marked ${ids.length} transactions as synced.');
            }

            break; // Success! exit loop
        } catch (e) {
            _statusController.add('Attempt ${i + 1} failed: $e');
        }
      }
      
      if (!success) {
         _addLog('Sync failed after $maxRetries attempts.');
         if (_useLan || _useNearby) {
           // Notify user of failure
           NotificationService().showSyncFailedNotification(
             'Failed to sync ${transactions.length} transactions after $maxRetries attempts.'
           );
         }
         // Do not restart indefinitely loops to avoid battery drain, 
         // wait for next trigger (e.g. new transaction or manual)
         _isSyncing = false;
      }

    } catch (e) {
      _statusController.add('Sync Failed: $e');
      debugPrint('Sync Failed: $e');
    } finally {
      _isBusySyncing = false;
    }
  }
}
