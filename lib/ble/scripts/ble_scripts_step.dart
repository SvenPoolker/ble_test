import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

enum BleScriptValueMode {
  text,
  hex,
}

class BleScriptStep {
  final String deviceId;
  final String? deviceName;
  final Uuid serviceId;
  final Uuid characteristicId;
  final List<int> value;
  final BleScriptValueMode mode;
  final DateTime timestamp;

  BleScriptStep({
    required this.deviceId,
    required this.deviceName,
    required this.serviceId,
    required this.characteristicId,
    required this.value,
    required this.mode,
    required this.timestamp,
  });
}
