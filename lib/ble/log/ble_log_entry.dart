enum BleLogType {
  advert,
  read,
  write,
  notify,
  connect,
  disconnect,
  error,
}

class BleLogEntry {
  final DateTime timestamp;
  final BleLogType type;
  final String deviceId;
  final String? deviceName;
  final String message;
  final List<int>? rawValue;

  BleLogEntry({
    required this.timestamp,
    required this.type,
    required this.deviceId,
    this.deviceName,
    required this.message,
    this.rawValue,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'type': type.name,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'message': message,
        'rawValue': rawValue,
      };
}
