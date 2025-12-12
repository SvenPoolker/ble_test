import 'dart:convert';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

class BleService {
  final FlutterReactiveBle _ble = FlutterReactiveBle();

  Stream<DiscoveredDevice> scanForDevices({
    List<Uuid> withServices = const [],
    ScanMode scanMode = ScanMode.balanced,
  }) {
    return _ble.scanForDevices(
      withServices: withServices,
      scanMode: scanMode,
    );
  }

  Stream<ConnectionStateUpdate> connectToDevice(String deviceId) {
    return _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: const Duration(seconds: 10),
    );
  }

  Future<List<DiscoveredService>> discoverServices(String deviceId) {
    return _ble.discoverServices(deviceId);
  }

  Future<List<int>> readCharacteristic({
      required String deviceId,
      required Uuid serviceId,
      required Uuid characteristicId,
    }) async {
      final qChar = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: serviceId,
        characteristicId: characteristicId,
      );

      return _ble.readCharacteristic(qChar);
    }

    Future<String> readDeviceName(String deviceId) async {
      final characteristic = QualifiedCharacteristic(
        serviceId: Uuid.parse("00001801-0000-1000-8000-00805f9b34fb"),
        characteristicId: Uuid.parse("00002a00-0000-1000-8000-00805f9b34fb"),
        deviceId: deviceId,
      );
    
      final value = await _ble.readCharacteristic(characteristic);
      return utf8.decode(value);
    }

    Future<List<int>> readRawCharacteristic({
      required String deviceId,
      required Uuid serviceId,
      required Uuid characteristicId,
    }) async {
      final c = QualifiedCharacteristic(
        deviceId: deviceId,
        serviceId: serviceId,
        characteristicId: characteristicId,
      );

      return _ble.readCharacteristic(c);
    }

  Stream<List<int>> subscribeToCharacteristic({
    required String deviceId,
    required Uuid serviceId,
    required Uuid characteristicId,
  }) {
    final c = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: serviceId,
      characteristicId: characteristicId,
    );

    return _ble.subscribeToCharacteristic(c);
  }

  Future<void> writeRawCharacteristic({
    required String deviceId,
    required Uuid serviceId,
    required Uuid characteristicId,
    required List<int> value,
    bool withResponse = true,
  }) async {
    final c = QualifiedCharacteristic(
      deviceId: deviceId,
      serviceId: serviceId,
      characteristicId: characteristicId,
    );

    if (withResponse) {
      await _ble.writeCharacteristicWithResponse(
        c,
        value: value,
      );
    } else {
      await _ble.writeCharacteristicWithoutResponse(
        c,
        value: value,
      );
    }
  }

}
