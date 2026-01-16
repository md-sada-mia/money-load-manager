
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'sync_provider.dart';
import '../models/sync_models.dart';

class NearbySyncService implements SyncProvider {
  final Strategy _strategy = Strategy.P2P_STAR;
  final String _userName = 'MoneyLoadUser'; // Should come from settings
  
  final _discoveredDevicesController = StreamController<SyncDevice>.broadcast();
  final _dataReceivedController = StreamController<SyncPacket>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  
  // Map endpointId -> SyncDeivce
  final Map<String, SyncDevice> _knownEndpoints = {};
  
  bool _isDiscovering = false;
  
  // Callback to check if sync manager is still syncing
  bool Function()? _shouldContinueDiscovery;
  
  void setup({bool Function()? shouldContinueDiscovery}) {
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
    try {
      bool a = await Nearby().startAdvertising(
        _userName,
        _strategy,
        serviceId: 'com.money_load_manager.money_load_manager', // Explicit Service ID
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: (id, status) {
          _statusController.add('Connection result: $status');
        },
        onDisconnected: (id) {
          _statusController.add('Disconnected: $id');
        },
      );
      if (a) _statusController.add('Advertising Nearby');
    } catch (e) {
      _statusController.add('Error advertising Nearby: $e');
    }
  }

  @override
  Future<void> stopAdvertising() async {
    await Nearby().stopAdvertising();
    _statusController.add('Stopped advertising Nearby');
  }

  @override
  Future<void> startDiscovery() async {
    try {
      bool a = await Nearby().startDiscovery(
        _userName,
        _strategy,
        serviceId: 'com.money_load_manager.money_load_manager', // Explicit Service ID
        onEndpointFound: (id, name, serviceId) {
          // Guard: Check if we should still process discovery events
          if (!_isDiscovering) {
            debugPrint('Nearby: Ignoring endpoint event - discovery flag is false');
            return;
          }
          
          if (_shouldContinueDiscovery != null && !_shouldContinueDiscovery!()) {
            debugPrint('Nearby: Ignoring endpoint event - sync manager not syncing');
            return;
          }
          
          _statusController.add('Nearby: Found endpoint $name ($id)');
          final device = SyncDevice(id: id, name: name, endpointId: id);
          _knownEndpoints[id] = device;
          _discoveredDevicesController.add(device);
        },
        onEndpointLost: (id) {
          _knownEndpoints.remove(id);
        },
      );
      if (a) {
        _isDiscovering = true;
        _statusController.add('Discovering Nearby');
      }
    } catch (e) {
      // 8002 = STATUS_ALREADY_DISCOVERING. This is fine, just means we are already running.
      if (e.toString().contains('8002') || e.toString().contains('ALREADY_DISCOVERING')) {
         debugPrint('Nearby: Already discovering (8002). Ignoring.');
         _statusController.add('Discovering Nearby (Continued)');
      } else {
         _statusController.add('Error discovering Nearby: $e');
      }
    }
  }

  @override
  Future<void> stopDiscovery() async {
    _isDiscovering = false;
    await Nearby().stopDiscovery();
    _statusController.add('Stopped discovering Nearby');
    debugPrint('Nearby: Discovery stopped.');
  }

  void _onConnectionInitiated(String id, ConnectionInfo info) async {
    _statusController.add('Nearby: Connection initiated from ${info.endpointName} ($id). Auto-accepting...');
    try {
      await Nearby().acceptConnection(
        id,
        onPayLoadRecieved: _onPayloadReceived,
      );
      _statusController.add('Nearby: Connection accepted for $id');
    } catch (e) {
      _statusController.add('Nearby: Error accepting connection from $id: $e');
    }
  }

  @override
  Future<void> sendData(String targetId, SyncPacket packet) async {
    try {
      final jsonStr = jsonEncode(packet.toJson());
      await Nearby().sendBytesPayload(targetId, Uint8List.fromList(utf8.encode(jsonStr)));
      _statusController.add('Data sent to $targetId');
    } catch (e) {
      _statusController.add('Error sending Nearby: $e');
    }
  }

  @override
  Future<bool> connect(String targetId) async {
    final completer = Completer<bool>();

    try {
      Nearby().requestConnection(
        _userName,
        targetId,
        onConnectionInitiated: (id, info) async {
          _statusController.add('Nearby: Connection initiated from ${info.endpointName} ($id). Auto-accepting...');
          try {
            await Nearby().acceptConnection(
              id,
              onPayLoadRecieved: _onPayloadReceived,
            );
             _statusController.add('Nearby: Connection accepted for $id');
          } catch (e) {
             _statusController.add('Nearby: Error accepting connection from $id: $e');
          }
        },
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            _statusController.add('Connected to $id');
            if (!completer.isCompleted) completer.complete(true);
          } else {
            _statusController.add('Connection failed: $status');
            if (!completer.isCompleted) completer.complete(false);
          }
        },
        onDisconnected: (id) {
          _statusController.add('Disconnected: $id');
        },
      );
    } catch (e) {
      _statusController.add('Error requesting connection: $e');
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }
  
  void _onPayloadReceived(String endId, Payload payload) {
      if (payload.type == PayloadType.BYTES) {
         final bytes = payload.bytes!;
         final jsonStr = utf8.decode(bytes);
         try {
           final packet = SyncPacket.fromJson(jsonDecode(jsonStr));
           _dataReceivedController.add(packet);
         } catch (e) {
           debugPrint('Nearby: Invalid packet');
         }
      }
  }

  @override
  Future<void> disconnect() async {
    await Nearby().stopAllEndpoints();
  }
}
