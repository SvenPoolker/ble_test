import 'dart:async';
import 'dart:convert';

import 'package:firsdt_app/ble/log/ble_log_entry.dart';
import 'package:firsdt_app/ble/log/ble_log_state.dart';
import 'package:firsdt_app/ble/playbooks/ble_playbook.dart';
import 'package:firsdt_app/ble/services/ble_service.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BlePlaybookResult {
  final bool success;
  final String message;

  BlePlaybookResult({required this.success, required this.message});
}

class BlePlaybookRunner {
  final BleService ble;
  final BleLogState logState;

  BlePlaybookRunner({required this.ble, required this.logState});

  Future<BlePlaybookResult> run(BlePlaybook playbook) async {
    StreamSubscription<ConnectionStateUpdate>? connectionSub;
    try {
      for (final step in playbook.steps) {
        switch (step.type) {
          case BlePlaybookStepType.connect:
            if (step.deviceId == null) {
              return BlePlaybookResult(
                success: false,
                message: 'Connect step missing deviceId',
              );
            }
            final result = await _connect(step.deviceId!, logName: playbook.name);
            connectionSub = result;
            break;
          case BlePlaybookStepType.write:
            final target = _requireTarget(step);
            if (target == null) {
              return BlePlaybookResult(success: false, message: 'Write step missing target');
            }
            await ble.writeRawCharacteristic(
              deviceId: target.deviceId,
              serviceId: target.serviceId,
              characteristicId: target.characteristicId,
              value: step.payload ?? [],
            );
            logState.add(
              BleLogEntry(
                timestamp: DateTime.now(),
                type: BleLogType.write,
                deviceId: target.deviceId,
                deviceName: null,
                message: 'Playbook write ${step.payload?.length ?? 0} bytes to ${target.characteristicId}',
                rawValue: step.payload,
              ),
            );
            break;
          case BlePlaybookStepType.wait:
            await Future.delayed(Duration(milliseconds: step.delayMs ?? 500));
            break;
          case BlePlaybookStepType.waitNotify:
            final target = _requireTarget(step);
            if (target == null) {
              return BlePlaybookResult(success: false, message: 'Notify step missing target');
            }
            final ok = await _listenForNotify(
              target: target,
              contains: step.expectContains,
              onMatchWrite: step.onMatchWrite,
              maxAttempts: step.maxAttempts ?? 5,
            );
            if (!ok) {
              return BlePlaybookResult(
                success: false,
                message: 'No matching notification received',
              );
            }
            break;
        }
      }
      return BlePlaybookResult(success: true, message: 'Playbook finished');
    } catch (e) {
      return BlePlaybookResult(success: false, message: 'Playbook error: $e');
    } finally {
      await connectionSub?.cancel();
    }
  }

  ({String deviceId, Uuid serviceId, Uuid characteristicId})? _requireTarget(
    BlePlaybookStep step,
  ) {
    if (step.deviceId == null || step.serviceId == null || step.characteristicId == null) {
      return null;
    }
    return (
      deviceId: step.deviceId!,
      serviceId: step.serviceId!,
      characteristicId: step.characteristicId!,
    );
  }

  Future<StreamSubscription<ConnectionStateUpdate>> _connect(
    String deviceId, {
    required String logName,
  }) async {
    final completer = Completer<void>();
    late final StreamSubscription<ConnectionStateUpdate> sub;

    sub = ble.connectToDevice(deviceId).listen((event) {
      logState.add(
        BleLogEntry(
          timestamp: DateTime.now(),
          type: BleLogType.connect,
          deviceId: deviceId,
          deviceName: logName,
          message: 'Playbook connection: ${event.connectionState}',
        ),
      );
      if (event.connectionState == DeviceConnectionState.connected) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
      if (event.connectionState == DeviceConnectionState.disconnected) {
        if (!completer.isCompleted) {
          completer.completeError('Disconnected before completion');
        }
      }
    }, onError: (e) {
      if (!completer.isCompleted) {
        completer.completeError(e);
      }
    });

    await completer.future.timeout(const Duration(seconds: 10));
    return sub;
  }

  Future<bool> _listenForNotify({
    required ({String deviceId, Uuid serviceId, Uuid characteristicId}) target,
    String? contains,
    List<int>? onMatchWrite,
    required int maxAttempts,
  }) async {
    final stream = ble.subscribeToCharacteristic(
      deviceId: target.deviceId,
      serviceId: target.serviceId,
      characteristicId: target.characteristicId,
    );

    try {
      var attempts = 0;
      await for (final data in stream.take(maxAttempts)) {
        attempts++;
        final hex = data.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        final ascii = _safeAscii(data);
        final payloadString = '$hex | $ascii';
        logState.add(
          BleLogEntry(
            timestamp: DateTime.now(),
            type: BleLogType.notify,
            deviceId: target.deviceId,
            deviceName: null,
            message: 'Playbook notify: $payloadString',
            rawValue: data,
          ),
        );

        final hasPattern = contains == null || payloadString.contains(contains);
        if (hasPattern) {
          if (onMatchWrite != null && onMatchWrite.isNotEmpty) {
            await ble.writeRawCharacteristic(
              deviceId: target.deviceId,
              serviceId: target.serviceId,
              characteristicId: target.characteristicId,
              value: onMatchWrite,
            );
          }
          return true;
        }

        if (attempts >= maxAttempts) {
          return false;
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  String _safeAscii(List<int> data) {
    try {
      return utf8.decode(data);
    } catch (_) {
      return data.toString();
    }
  }
}
