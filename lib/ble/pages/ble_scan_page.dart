import 'dart:async';
import 'package:firsdt_app/ble/log/ble_log_entry.dart';
import 'package:firsdt_app/ble/log/ble_log_state.dart';
import 'package:firsdt_app/ble/pages/ble_device_page.dart';
import 'package:firsdt_app/ble/services/ble_service.dart';

import 'package:firsdt_app/utils/company_identifiers.dart';
import 'package:firsdt_app/utils/gatt_defs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class BleScanPage extends StatefulWidget {
  const BleScanPage({super.key});

  @override
  State<BleScanPage> createState() => _BleScanPageState();
}

class _BleScanPageState extends State<BleScanPage> {
  final BleService ble = BleService();
  final Map<String, String> _charValues = {};
  final TextEditingController _nameFilterController = TextEditingController();
  final TextEditingController _prefixFilterController = TextEditingController();
  double _minRssi = -100;
  bool _logAdverts = false;


  final List<DiscoveredDevice> _devices = [];
  StreamSubscription<DiscoveredDevice>? _scanSub;
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;

  bool _isScanning = false;
  String _connectionStatus = "";
  List<DiscoveredService> _discoveredServices = [];

  String _formatUUID(Uuid uuid) {
    final expanded = uuid.data.length == 16 ? uuid : uuid.expanded;
    return expanded.toString().toLowerCase();
  }

  String _humanServiceName(String uuid) => GattDefs.services[uuid.toLowerCase()] ?? "Unknown service";

  String _humanCharName(String uuid) => GattDefs.characteristics[uuid.toLowerCase()] ?? "Unknown characteristic";

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStartScan();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _connectionSub?.cancel();
    _nameFilterController.dispose();
    _prefixFilterController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionsAndStartScan() async {
    // Adjust permissions depending on your target SDK
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final location = await Permission.locationWhenInUse.request();

    if (bluetoothScan.isGranted &&
        bluetoothConnect.isGranted &&
        location.isGranted) {
      _startScan();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions BLE refusées')),
        );
      }
    }
  }

  void _startScan() {
    _scanSub?.cancel();
    setState(() {
      _devices.clear();
      _isScanning = true;
    });
  
    _scanSub = ble.scanForDevices().listen(
      (device) {
        final index = _devices.indexWhere((d) => d.id == device.id);
        setState(() {
          if (index == -1) {
            _devices.add(device);
          } else {
            _devices[index] = device;
          }
        });
  
        if (_logAdverts) {
          final logState = context.read<BleLogState>();
          logState.add(
            BleLogEntry(
              timestamp: DateTime.now(),
              type: BleLogType.advert,
              deviceId: device.id,
              deviceName: device.name,
              message: "Advert: name='${device.name}', rssi=${device.rssi}",
              rawValue: null,
            ),
          );
        }
      },
      onError: (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur scan: $e')),
          );
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
      },
    );
  }

  void _stopScan() {
    _scanSub?.cancel();
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _connectToDevice(
    DiscoveredDevice device, {
    void Function(void Function())? setDialogState,
  }) async {
    await _connectionSub?.cancel();

    void updateState(void Function() fn) {
      if (setDialogState != null) {
        setDialogState(fn);
      } else if (mounted) {
        setState(fn);
      }
    }

    updateState(() {
      _connectionStatus = "Connexion à ${device.name}...";
      _discoveredServices = [];
    });

    _connectionSub = ble.connectToDevice(device.id).listen(
      (event) async {
        updateState(() {
          _connectionStatus = event.connectionState.toString();
        });

        if (event.connectionState == DeviceConnectionState.connected) {
          try {
            final services = await ble.discoverServices(device.id);
            updateState(() {
              _discoveredServices = services;
            });
          } catch (e) {
            updateState(() {
              _connectionStatus = "Erreur découverte services: $e";
            });
          }
        }
      },
      onError: (e) {
        updateState(() {
          _connectionStatus = "Erreur connexion: $e";
        });
      },
    );
  }

  Future<void> _disconnect() async {
    await _connectionSub?.cancel();
    setState(() {
      _connectionStatus = "Déconnecté";
    });
  }

  Future<void> _showDeviceDialog(DiscoveredDevice device) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // First time: kick off connection
            if (_connectionSub == null) {
              _connectToDevice(device, setDialogState: setDialogState);
            }

            return AlertDialog(
              title: Text(
                device.name.isNotEmpty ? device.name : device.id,
                style: const TextStyle(fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _connectionStatus,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_discoveredServices.isEmpty)
                    const Text(
                      "Aucun service découvert pour l'instant.\n"
                      "Attends que la connexion soit établie.",
                    )
                  else
                    SizedBox(
                      width: double.maxFinite,
                      height: 260,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _discoveredServices.length,
                        itemBuilder: (context, index) {
                          final service = _discoveredServices[index];
                          final serviceId = _formatUUID(service.serviceId);
                          final serviceName = _humanServiceName(serviceId);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Service: $serviceName",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                serviceId,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (service.characteristics.isNotEmpty)
                                const Text(
                                  "Characteristics:",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ...service.characteristics.map(
                                (c) {
                                  final characteristicId =
                                      _formatUUID(c.characteristicId);
                                  final charName =
                                      _humanCharName(characteristicId);
                                  final key =
                                      "$serviceId::$characteristicId";
                                  final value = _charValues[key];

                                  return InkWell(
                                    onTap: () async {
                                      try {
                                        final data =
                                            await ble.readCharacteristic(
                                          deviceId: device.id,
                                          serviceId: service.serviceId,
                                          characteristicId:
                                              c.characteristicId,
                                        );

                                        final hex = data
                                            .map((b) => b
                                                .toRadixString(16)
                                                .padLeft(2, '0'))
                                            .join(' ');
                                        setDialogState(() {
                                          _charValues[key] = hex;
                                        });
                                      } catch (e) {
                                        setDialogState(() {
                                          _charValues[key] =
                                              "Erreur lecture: $e";
                                        });
                                      }
                                    },
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.symmetric(
                                              vertical: 2),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "- $charName",
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            characteristicId,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontStyle:
                                                  FontStyle.italic,
                                            ),
                                          ),
                                          if (value != null)
                                            Text(
                                              value,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ).toList(),
                              const Divider(),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await _disconnect();
                    if (context.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text("Fermer"),
                ),
              ],
            );
          },
        );
      },
    );

    // Reset connection state after dialog closes
    _connectionSub?.cancel();
    setState(() {
      _connectionSub = null;
      _connectionStatus = "";
      _discoveredServices = [];
    });
  }

Widget _buildFilters() {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Filtres",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameFilterController,
              decoration: const InputDecoration(
                labelText: "Filtre nom / ID",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _prefixFilterController,
              decoration: const InputDecoration(
                labelText: "Préfixe",
                prefixIcon: Icon(Icons.filter_alt),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text("RSSI min"),
                Expanded(
                  child: Slider(
                    min: -100,
                    max: 0,
                    value: _minRssi,
                    onChanged: (v) {
                      setState(() {
                        _minRssi = v;
                      });
                    },
                  ),
                ),
                Text("${_minRssi.toInt()} dBm"),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Log adverts"),
                Switch(
                  value: _logAdverts,
                  onChanged: (v) {
                    setState(() {
                      _logAdverts = v;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final filteredDevices = _devices.where((d) {
      final name = d.name.toLowerCase();
      final id = d.id.toLowerCase();

      final nameFilter = _nameFilterController.text.toLowerCase();
      final prefixFilter = _prefixFilterController.text.toLowerCase();

      if (nameFilter.isNotEmpty &&
          !name.contains(nameFilter) &&
          !id.contains(nameFilter)) {
        return false;
      }

      if (prefixFilter.isNotEmpty &&
          !name.startsWith(prefixFilter) &&
          !id.startsWith(prefixFilter)) {
        return false;
      }

      if (d.rssi < _minRssi) return false;

      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan BLE"),
        actions: [
          IconButton(
            icon: Icon(_isScanning ? Icons.stop : Icons.refresh),
            tooltip: _isScanning ? "Arrêter le scan" : "Relancer le scan",
            onPressed: () {
              if (_isScanning) {
                _stopScan();
              } else {
                _startScan();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(
            
            child: filteredDevices.isEmpty
                ? const Center(
                    child: Text("Aucun périphérique après filtrage"),
                  )
                : ListView.builder(
                    itemCount: filteredDevices.length,
                    itemBuilder: (context, index) {
                      final device = filteredDevices[index];
                      final mfgBytes = device.manufacturerData;
                      final services = device.serviceUuids;

                      int? mfgId;
                      if (mfgBytes.length >= 2) {
                        mfgId = (mfgBytes[1] << 8) | mfgBytes[0];
                      }
                      final mfgName = mfgId != null ? CompanyIdentifiers.lookup(mfgId) : null;

                      return ListTile(
                        dense: true,
                        title: Text(
                          device.name.isNotEmpty ? device.name : "Inconnu",
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.id,
                              style: const TextStyle(fontSize: 11),
                            ),
                            Text(
                              "Services: ${services.length}"
                              "${mfgName != null ? " · MFG: $mfgName" : ""}",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: Text(
                          "${device.rssi} dBm",
                          style: const TextStyle(
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BleDevicePage(
                                device: device,
                                ble: ble,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_isScanning) {
            _stopScan();
          } else {
            _startScan();
          }
        },
        child: Icon(_isScanning ? Icons.stop : Icons.search),
      ),
    );
  }

}

