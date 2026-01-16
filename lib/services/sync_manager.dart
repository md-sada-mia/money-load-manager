
import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/models.dart';
import '../models/sync_models.dart';
import 'lan_sync_service.dart';
import 'nearby_sync_service.dart';
import 'sync_provider.dart';

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  final LanSyncService _lanService = LanSyncService();
  final NearbySyncService _nearbyService = NearbySyncService();

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

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final roleIndex = prefs.getInt('sync_role') ?? 1; // Default Worker
    _role = SyncRole.values[roleIndex];
    
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
    // specific listeners for providers
    _lanService.dataReceived.listen(_handleDataReceived);
    _nearbyService.dataReceived.listen(_handleDataReceived);
    
    // Listen for Discovery (Worker Logic)
    _lanService.discoveredDevices.listen((device) => _handleDiscoveredDevice(device, _lanService));
    _nearbyService.discoveredDevices.listen((device) => _handleDiscoveredDevice(device, _nearbyService));
  }

  // ... (setRole, role, startSync, stopSync same as above, keeping them intact/implicit)

  Future<bool> _checkPermissions() async {
    List<Permission> permissions = [];
    
    // Always needed
    permissions.add(Permission.location);
    
    // Android 12+ (API 31+)
    if (Platform.isAndroid) {
       // Android 12 (API 31) needs Bluetooth permissions for Nearby
       if (_sdkInt >= 31) {
         permissions.addAll([
           Permission.bluetoothAdvertise,
           Permission.bluetoothConnect,
           Permission.bluetoothScan,
         ]);
       }
       
       // Android 13 (API 33) needs Nearby Wifi Devices
       if (_sdkInt >= 33) {
         permissions.add(Permission.nearbyWifiDevices); 
       }
    }

    Map<Permission, PermissionStatus> statuses = await permissions.request();
    
    bool allGranted = true;
    List<String> deniedList = [];

    statuses.forEach((permission, status) {
      if (!status.isGranted) {
        // Strict consistency check: Fail if denied or permanently denied
        if (status.isDenied || status.isPermanentlyDenied) {
           allGranted = false;
           deniedList.add(permission.toString());
        }
      }
    });

    if (!allGranted) {
      _statusController.add('Missing Permissions: ${deniedList.join(', ')}');
      debugPrint('Sync: Missing Permissions: $deniedList');
    }
    
    return allGranted;
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
    if (_isSyncing) return;
    
    // Check Permissions
    if (!await _checkPermissions()) {
      _addLog('Missing Permissions');
      return;
    }

    _isSyncing = true;
    _statusController.add('Starting Sync Service...');

    if (_role == SyncRole.master) {
      // Master: Start Advertising on BOTH channels
      await _lanService.startAdvertising();
      await _nearbyService.startAdvertising();
       _addLog('Master Mode Active: Waiting for connections...');
    } else {
      // Worker: Attempt Hybrid Discovery
      // Priority 1: LAN
      _addLog('Checking LAN for Master...');
      await _lanService.startDiscovery();
      
      // We wait a bit to see if we find anything on LAN
      // Simplified Hybrid Logic:
      // Start LAN. After 5 seconds, if not connected (no device found), Start Nearby.
      
      _fallbackTimer?.cancel(); // Ensure clear before starting
      _fallbackTimer = Timer(const Duration(seconds: 5), () async {
        // Only start nearby if we haven't found a LAN device (checked via cancellation or flag)
        if (_isSyncing) {
           _addLog('No LAN Master found in 5s. Starting Nearby Discovery (Fallback)...');
           await _nearbyService.startDiscovery();
        }
      });
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
      // 1. Fetch ALL transactions
      final transactions = await DatabaseHelper.instance.getAllTransactions();
      
      if (transactions.isEmpty) {
         _statusController.add('No transactions to sync.');
         _isBusySyncing = false;
         return;
      }
      
      _statusController.add('Sending ${transactions.length} transactions...');

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
      int maxRetries = 3;
      bool success = false;
      
      for (int i = 0; i < maxRetries; i++) {
        if (i > 0) {
           _statusController.add('Retry ${i + 1}/$maxRetries...');
           await Future.delayed(const Duration(seconds: 2)); // Wait before retry
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
            break; // Success! exit loop
        } catch (e) {
            _statusController.add('Attempt ${i + 1} failed: $e');
        }
      }
      
      if (!success) {
         _statusController.add('Sync Aborted after $maxRetries failed attempts.');
      }

    } catch (e) {
      _statusController.add('Sync Failed: $e');
      debugPrint('Sync Failed: $e');
    } finally {
      _isBusySyncing = false;
    }
  }
}
