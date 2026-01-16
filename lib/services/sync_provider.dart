
import '../models/sync_models.dart';
import '../models/models.dart';

abstract class SyncProvider {
  /// Start advertising this device as a Master
  Future<void> startAdvertising();

  /// Stop advertising
  Future<void> stopAdvertising();

  /// Start discovering Master devices
  Future<void> startDiscovery();

  /// Stop discovery
  Future<void> stopDiscovery();

  /// Connect to a device (required for Neighbor/P2P, optional for LAN)
  Future<bool> connect(String targetId);

  /// Send data to a connected device
  Future<void> sendData(String targetId, SyncPacket packet);

  /// Disconnect from a device
  Future<void> disconnect();

  /// Stream of discovered devices
  Stream<SyncDevice> get discoveredDevices;

  /// Stream of received data
  Stream<SyncPacket> get dataReceived;
  
  /// Stream of connection status
  Stream<String> get connectionStatus;
}

enum SyncRole { master, worker }
