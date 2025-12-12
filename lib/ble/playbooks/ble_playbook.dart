import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

enum BlePlaybookStepType {
  connect,
  write,
  wait,
  waitNotify,
}

class BlePlaybookStep {
  final BlePlaybookStepType type;
  final String? deviceId;
  final Uuid? serviceId;
  final Uuid? characteristicId;
  final List<int>? payload;
  final int? delayMs;
  final String? expectContains;
  final List<int>? onMatchWrite;
  final int? maxAttempts;

  const BlePlaybookStep({
    required this.type,
    this.deviceId,
    this.serviceId,
    this.characteristicId,
    this.payload,
    this.delayMs,
    this.expectContains,
    this.onMatchWrite,
    this.maxAttempts,
  });

  factory BlePlaybookStep.connect(String deviceId) {
    return BlePlaybookStep(type: BlePlaybookStepType.connect, deviceId: deviceId);
  }

  factory BlePlaybookStep.write({
    required String deviceId,
    required Uuid serviceId,
    required Uuid characteristicId,
    required List<int> payload,
  }) {
    return BlePlaybookStep(
      type: BlePlaybookStepType.write,
      deviceId: deviceId,
      serviceId: serviceId,
      characteristicId: characteristicId,
      payload: payload,
    );
  }

  factory BlePlaybookStep.wait(Duration duration) {
    return BlePlaybookStep(type: BlePlaybookStepType.wait, delayMs: duration.inMilliseconds);
  }

  factory BlePlaybookStep.waitNotify({
    required String deviceId,
    required Uuid serviceId,
    required Uuid characteristicId,
    String? expectContains,
    List<int>? onMatchWrite,
    int? maxAttempts,
  }) {
    return BlePlaybookStep(
      type: BlePlaybookStepType.waitNotify,
      deviceId: deviceId,
      serviceId: serviceId,
      characteristicId: characteristicId,
      expectContains: expectContains,
      onMatchWrite: onMatchWrite,
      maxAttempts: maxAttempts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'deviceId': deviceId,
      'serviceId': serviceId?.toString(),
      'characteristicId': characteristicId?.toString(),
      'payload': payload,
      'delayMs': delayMs,
      'expectContains': expectContains,
      'onMatchWrite': onMatchWrite,
      'maxAttempts': maxAttempts,
    };
  }

  factory BlePlaybookStep.fromJson(Map<String, dynamic> json) {
    return BlePlaybookStep(
      type: BlePlaybookStepType.values.byName(json['type'] as String),
      deviceId: json['deviceId'] as String?,
      serviceId: json['serviceId'] != null ? Uuid.parse(json['serviceId'] as String) : null,
      characteristicId: json['characteristicId'] != null
          ? Uuid.parse(json['characteristicId'] as String)
          : null,
      payload: (json['payload'] as List?)?.map((e) => e as int).toList(),
      delayMs: json['delayMs'] as int?,
      expectContains: json['expectContains'] as String?,
      onMatchWrite: (json['onMatchWrite'] as List?)?.map((e) => e as int).toList(),
      maxAttempts: json['maxAttempts'] as int?,
    );
  }

  String describe() {
    switch (type) {
      case BlePlaybookStepType.connect:
        return 'Connect to $deviceId';
      case BlePlaybookStepType.write:
        return 'Write ${payload?.length ?? 0} bytes to ${characteristicId ?? '?'}';
      case BlePlaybookStepType.wait:
        return 'Wait ${delayMs ?? 0} ms';
      case BlePlaybookStepType.waitNotify:
        final base = 'Wait notify on ${characteristicId ?? '?'}';
        final cond = expectContains != null ? " (until contains '$expectContains')" : '';
        return '$base$cond';
    }
  }
}

class BlePlaybook {
  final String name;
  final String description;
  final List<BlePlaybookStep> steps;

  const BlePlaybook({
    required this.name,
    required this.description,
    required this.steps,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'steps': steps.map((e) => e.toJson()).toList(),
      };

  factory BlePlaybook.fromJson(Map<String, dynamic> json) {
    return BlePlaybook(
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      steps: (json['steps'] as List)
          .map((e) => BlePlaybookStep.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
