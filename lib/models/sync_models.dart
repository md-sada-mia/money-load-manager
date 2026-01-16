
class SyncPacket {
  final String deviceId;
  final String deviceName;
  final int timestamp;
  final List<Map<String, dynamic>> transactions;
  final String protocolVersion;

  SyncPacket({
    required this.deviceId,
    required this.deviceName,
    required this.timestamp,
    required this.transactions,
    this.protocolVersion = '1.0',
  });

  Map<String, dynamic> toJson() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'timestamp': timestamp,
      'transactions': transactions,
      'protocolVersion': protocolVersion,
    };
  }

  factory SyncPacket.fromJson(Map<String, dynamic> json) {
    return SyncPacket(
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      timestamp: json['timestamp'],
      transactions: List<Map<String, dynamic>>.from(json['transactions']),
      protocolVersion: json['protocolVersion'] ?? '1.0',
    );
  }
}

class SyncDevice {
  final String id;
  final String name;
  final String? ipAddress; // For LAN
  final int? servicePort; // For LAN
  final String? endpointId; // For Nearby
  final bool isTrusted;
  final int lastSyncTime;

  SyncDevice({
    required this.id,
    required this.name,
    this.ipAddress,
    this.servicePort,
    this.endpointId,
    this.isTrusted = false,
    this.lastSyncTime = 0,
  });
}
