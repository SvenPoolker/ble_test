import 'dart:async';
import 'package:firsdt_app/ble/scripts/ble_script_state.dart';
import 'package:firsdt_app/ble/scripts/ble_scripts_step.dart';
import 'package:firsdt_app/utils/gatt_defs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:firsdt_app/ble/services/ble_service.dart';
import 'package:provider/provider.dart';
import 'package:firsdt_app/ble/log/ble_log_state.dart';
import 'package:firsdt_app/ble/log/ble_log_entry.dart';


class BleDevicePage extends StatefulWidget {
  final DiscoveredDevice device;
  final BleService ble;

  const BleDevicePage({
    super.key,
    required this.device,
    required this.ble,
  });

  @override
  State<BleDevicePage> createState() => _BleDevicePageState();
}

class _BleDevicePageState extends State<BleDevicePage> {
  StreamSubscription<ConnectionStateUpdate>? _connectionSub;

  String _connectionStatus = "Non connecté";
  DeviceConnectionState? _lastConnectionState;
  List<DiscoveredService> _discoveredServices = [];
  String? _deviceNameValue;
  final Map<String, StreamSubscription<List<int>>> _notifySubs = {};
  final Map<String, List<int>> _lastNotifiedValue = {};
  final TextEditingController _writeController = TextEditingController();
  bool get _anyNotificationEnabled => _notifySubs.isNotEmpty;


  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    for (final sub in _notifySubs.values) {
      sub.cancel();
    }
    _writeController.dispose();
    super.dispose();
  }

  String _charKey(Uuid serviceId, Uuid charId) => "${serviceId.toString()}|${charId.toString()}";

  List<String> _computeVulnHeuristics(
    DiscoveredService service,
    DiscoveredCharacteristic charac,
  ) {
    final uuid = charac.characteristicId.toString().toLowerCase();
    final isWritable = charac.isWritableWithResponse || charac.isWritableWithoutResponse;
    final reasons = <String>[];

    if (isWritable && GattDefs.writableInfoCharacteristics.contains(uuid)) {
      reasons.add('Characteristic writable sans auth détectée');
    }

    if (charac.isNotifiable &&
        GattDefs.dataNotificationCharacteristics.contains(uuid)) {
      reasons.add('Notify actif sans encryption apparente');
    }

    if (charac.isWritableWithoutResponse &&
        GattDefs.writableInfoCharacteristics.contains(uuid)) {
      reasons.add('Write without response sur char sensible');
    }

    if (isWritable && GattDefs.fragileWriteCharacteristics.contains(uuid)) {
      reasons.add('Payload long/invalid pourrait faire crasher le device');
    }

    return reasons;
  }

  Future<void> _onConnectPressed() async {
    await _connectionSub?.cancel();

    setState(() {
      _connectionStatus = "Connexion...";
      _discoveredServices = [];
      _deviceNameValue = null;
    });

    final logState = context.read<BleLogState>();

    _connectionSub = widget.ble
        .connectToDevice(widget.device.id)
        .listen((event) async {
      if (!mounted) return;

      setState(() {
        _connectionStatus = event.connectionState.toString();
      });
      _lastConnectionState = event.connectionState;

      if (event.connectionState == DeviceConnectionState.connected) {
        try {
          logState.add(
            BleLogEntry(
              timestamp: DateTime.now(),
              type: BleLogType.connect,
              deviceId: widget.device.id,
              deviceName: widget.device.name,
              message: "Connected",
            ),
          );
          final services =
              await widget.ble.discoverServices(widget.device.id);
          // lecture optionnelle du 0x2A00 (device name)
          String? name;
          try {
            name = await widget.ble.readDeviceName(widget.device.id);
          } catch (_) {
            // pas grave si ça échoue
          }

          if (!mounted) return;
          setState(() {
            _discoveredServices = services;
            _deviceNameValue = name;
          });
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _connectionStatus = "Erreur découverte/lecture: $e";
          });
        }
      }
    }, onError: (e) {
      if (!mounted) return;
      setState(() {
        _connectionStatus = "Erreur connexion: $e";
      });
    });
  }

  Future<void> _onDisconnectPressed() async {
    await _connectionSub?.cancel();
    final logState = context.read<BleLogState>();
    logState.add(
      BleLogEntry(
        timestamp: DateTime.now(),
        type: BleLogType.disconnect,
        deviceId: widget.device.id,
        deviceName: widget.device.name,
        message: "Manual disconnect",
      ),
    );
    setState(() {
      _connectionStatus = "Déconnecté";
      _lastConnectionState = DeviceConnectionState.disconnected;
      _discoveredServices = [];
      _deviceNameValue = null;
    });
  }

  Future<void> _onReadCharacteristic(
    Uuid serviceId,
    Uuid characteristicId,
  ) async {
    try {
      final raw = await widget.ble.readRawCharacteristic(
        deviceId: widget.device.id,
        serviceId: serviceId,
        characteristicId: characteristicId,
      );
      final logState = context.read<BleLogState>();
      logState.add(
        BleLogEntry(
          timestamp: DateTime.now(),
          type: BleLogType.read,
          deviceId: widget.device.id,
          deviceName: widget.device.name,
          message: "Read from $characteristicId",
          rawValue: raw,
        ),
      );

      if (!mounted) return;

      final hex =
          raw.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      final ascii = String.fromCharCodes(raw);

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text("Characteristic ${characteristicId.toString()}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Raw bytes: $raw"),
              const SizedBox(height: 8),
              Text("Hex: $hex"),
              const SizedBox(height: 8),
              Text("ASCII: $ascii"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fermer"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur lecture: $e")),
      );
    }
  }

  Future<void> _toggleNotify(
    DiscoveredService service,
    DiscoveredCharacteristic charac,
  ) async {
    final key = _charKey(service.serviceId, charac.characteristicId);

    // Si déjà abonné → on arrête
    if (_notifySubs.containsKey(key)) {
      await _notifySubs[key]?.cancel();
      setState(() {
        _notifySubs.remove(key);
        _lastNotifiedValue.remove(key);
      });
      return;
    }

    // Sinon on s'abonne
    try {
      final sub = widget.ble
          .subscribeToCharacteristic(
            deviceId: widget.device.id,
            serviceId: service.serviceId,
            characteristicId: charac.characteristicId,
          )
          .listen((data) {
            final logState = context.read<BleLogState>();
            logState.add(
              BleLogEntry(
                timestamp: DateTime.now(),
                type: BleLogType.notify,
                deviceId: widget.device.id,
                deviceName: widget.device.name,
                message: "Notify from ${charac.characteristicId}",
                rawValue: data,
              ),
            );
        setState(() {
          _lastNotifiedValue[key] = data;
        });
      }, onError: (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur notify: $e")),
        );
      });

      setState(() {
        _notifySubs[key] = sub;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur subscribe: $e")),
      );
    }
  }

  List<int> _parseHex(String input) {
    final clean = input.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (clean.length % 2 != 0) {
      throw FormatException("Hex string length must be even");
    }

    final result = <int>[];
    for (var i = 0; i < clean.length; i += 2) {
      final byteStr = clean.substring(i, i + 2);
      result.add(int.parse(byteStr, radix: 16));
    }
    return result;
  }

  Future<void> _showWriteDialog( DiscoveredService service, DiscoveredCharacteristic charac,) async {
    _writeController.clear();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Write ${charac.characteristicId}"),
        content: TextField(
          controller: _writeController,
          decoration: const InputDecoration(
            labelText: "Texte ou hex (ex: 01 0A FF)",
          ),
          minLines: 1,
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () async {
              // Send as TEXT (UTF-8)
              final text = _writeController.text;
              final bytes = text.codeUnits; // ou utf8.encode(text)
              try {
                await widget.ble.writeRawCharacteristic(
                  deviceId: widget.device.id,
                  serviceId: service.serviceId,
                  characteristicId: charac.characteristicId,
                  value: bytes,
                  withResponse: true,
                );
                final logState = context.read<BleLogState>();
                logState.add(
                  BleLogEntry(
                    timestamp: DateTime.now(),
                    type: BleLogType.write,
                    deviceId: widget.device.id,
                    deviceName: widget.device.name,
                    message: "Write TEXT to ${charac.characteristicId}: '$text'",
                    rawValue: bytes,
                  ),
                );
                final scriptState = context.read<BleScriptState>();
                scriptState.addStep(
                  BleScriptStep(
                    deviceId: widget.device.id,
                    deviceName: widget.device.name,
                    serviceId: service.serviceId,
                    characteristicId: charac.characteristicId,
                    value: bytes,
                    mode: BleScriptValueMode.text,
                    timestamp: DateTime.now(),
                  ),
                );
                if (mounted) Navigator.pop(context);
                
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Erreur write (texte): $e")),
                );
              }
            },
            child: const Text("Send TEXT"),
          ),
          TextButton(
            onPressed: () async {
              // Send as HEX
              final text = _writeController.text;
              try {
                final bytes = _parseHex(text);
                await widget.ble.writeRawCharacteristic(
                  deviceId: widget.device.id,
                  serviceId: service.serviceId,
                  characteristicId: charac.characteristicId,
                  value: bytes,
                  withResponse: true,
                );
                final logState = context.read<BleLogState>();
                logState.add(
                  BleLogEntry(
                    timestamp: DateTime.now(),
                    type: BleLogType.write,
                    deviceId: widget.device.id,
                    deviceName: widget.device.name,
                    message: "Write HEX to ${charac.characteristicId}: $text",
                    rawValue: bytes,
                  ),
                );
                final scriptState = context.read<BleScriptState>();
                scriptState.addStep(
                  BleScriptStep(
                    deviceId: widget.device.id,
                    deviceName: widget.device.name,
                    serviceId: service.serviceId,
                    characteristicId: charac.characteristicId,
                    value: bytes,
                    mode: BleScriptValueMode.hex,
                    timestamp: DateTime.now(),
                  ),
                );
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Erreur write (hex): $e")),
                );
              }
            },
            child: const Text("Send HEX"),
          ),
        ],
      ),
    );
  }

Future<void> _toggleAllNotifications() async {
  if (_discoveredServices.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Aucun service découvert pour l’instant.")),
    );
    return;
  }

  final notifiable = <(DiscoveredService, DiscoveredCharacteristic)>[];

  for (final service in _discoveredServices) {
    for (final charac in service.characteristics) {
      if (charac.isNotifiable) {
        notifiable.add((service, charac));
      }
    }
  }

  if (notifiable.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Aucune caractéristique notifiable.")),
    );
    return;
  }

  final enable = !_anyNotificationEnabled;

  for (final entry in notifiable) {
    final (service, charac) = entry;
    final key = _charKey(service.serviceId, charac.characteristicId);
    final isSubscribed = _notifySubs.containsKey(key);

    if (enable && !isSubscribed) {
      await _toggleNotify(service, charac);
    } else if (!enable && isSubscribed) {
      await _toggleNotify(service, charac);
    }
  }
}

Future<void> _replayScriptForCurrentDevice({int times = 1}) async {
  final scriptState = context.read<BleScriptState>();
  final steps = scriptState.steps
      .where((s) => s.deviceId == widget.device.id)
      .toList();

  if (steps.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Aucun step de script pour ce device.")),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text("Replaying ${steps.length} steps...")),
  );

for (var t = 0; t < times; t++) {
  for (final step in steps) {
    try {
      await widget.ble.writeRawCharacteristic(
        deviceId: widget.device.id,
        serviceId: step.serviceId,
        characteristicId: step.characteristicId,
        value: step.value,
        withResponse: true,
      );

      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur replay: $e")),
      );
      break;
    }
  }
  }

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text("Replay terminé.")),
  );
}

Future<void> _showReplayDialog() async {
  final scriptState = context.read<BleScriptState>();
  final steps = scriptState.steps
      .where((s) => s.deviceId == widget.device.id)
      .toList();

  if (steps.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Aucun step de script pour ce device.")),
    );
    return;
  }

  int selectedTimes = 1;

  await showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text("Replay script"),
        content: StatefulBuilder(
          builder: (ctx, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Combien de fois rejouer le script ?"),
                const SizedBox(height: 8),
                DropdownButton<int>(
                  value: selectedTimes,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text("1 fois")),
                    DropdownMenuItem(value: 5, child: Text("5 fois")),
                    DropdownMenuItem(value: 10, child: Text("10 fois")),
                    DropdownMenuItem(value: 50, child: Text("50 fois")),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      selectedTimes = value;
                    });
                  },
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _replayScriptForCurrentDevice(times: selectedTimes);
            },
            child: const Text("Lancer"),
          ),
        ],
      );
    },
  );
}

BleScriptStep? _getLastStepForCurrentDevice() {
  final scriptState = context.read<BleScriptState>();
  final stepsForDevice = scriptState.steps
      .where((s) => s.deviceId == widget.device.id)
      .toList();

  if (stepsForDevice.isEmpty) return null;
  return stepsForDevice.last;
}

Future<void> _showFuzzDialog() async {
  final step = _getLastStepForCurrentDevice();
  if (step == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Aucun step pour ce device à fuzz.")),
    );
    return;
  }

  if (step.value.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Valeur vide, rien à fuzz.")),
    );
    return;
  }

  // valeurs par défaut
  int byteIndex = step.value.length - 1;
  int minVal = 0x00;
  int maxVal = 0xFF;
  int delayMs = 50;
  bool useBoundaryValues = true;
  bool useBitFlips = true;
  bool testPayloadSizes = true;
  bool stopOnDisconnect = true;
  bool stopOnNotifyAnomaly = true;
  bool stopOnTimeout = true;
  bool autoReplayLastValid = true;
  int timeoutMs = 500;

  await showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text("Fuzz config"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Taille payload: ${step.value.length} bytes"),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Byte index (0-based)",
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null) {
                      setState(() {
                        byteIndex = parsed.clamp(0, step.value.length - 1);
                      });
                    }
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: "Min (hex, ex: 00)",
                        ),
                        onChanged: (v) {
                          final parsed = int.tryParse(v, radix: 16);
                          if (parsed != null) {
                            setState(() {
                              minVal = parsed.clamp(0, 255);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: "Max (hex, ex: FF)",
                        ),
                        onChanged: (v) {
                          final parsed = int.tryParse(v, radix: 16);
                          if (parsed != null) {
                            setState(() {
                              maxVal = parsed.clamp(0, 255);
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: const InputDecoration(
                    labelText: "Delay (ms)",
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null) {
                      setState(() {
                        delayMs = parsed.clamp(0, 1000);
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: useBoundaryValues,
                  dense: true,
                  title: const Text("Boundary values (0x00, 0x7F, 0xFF)"),
                  onChanged: (v) => setState(() => useBoundaryValues = v),
                ),
                SwitchListTile(
                  value: useBitFlips,
                  dense: true,
                  title: const Text("Bit flip (1-bit mutations)"),
                  onChanged: (v) => setState(() => useBitFlips = v),
                ),
                SwitchListTile(
                  value: testPayloadSizes,
                  dense: true,
                  title: const Text("Payload trop long / trop court"),
                  onChanged: (v) => setState(() => testPayloadSizes = v),
                ),
                const Divider(height: 20),
                SwitchListTile(
                  value: stopOnDisconnect,
                  dense: true,
                  title: const Text("Stop si déconnexion"),
                  onChanged: (v) => setState(() => stopOnDisconnect = v),
                ),
                SwitchListTile(
                  value: stopOnNotifyAnomaly,
                  dense: true,
                  title: const Text("Stop si notify incohérente"),
                  onChanged: (v) => setState(() => stopOnNotifyAnomaly = v),
                ),
                SwitchListTile(
                  value: stopOnTimeout,
                  dense: true,
                  title: const Text("Stop sur timeout écriture"),
                  onChanged: (v) => setState(() => stopOnTimeout = v),
                ),
                if (stopOnTimeout)
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Timeout écriture (ms)",
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final parsed = int.tryParse(v);
                      if (parsed != null && parsed > 0) {
                        setState(() {
                          timeoutMs = parsed;
                        });
                      }
                    },
                  ),
                SwitchListTile(
                  value: autoReplayLastValid,
                  dense: true,
                  title: const Text("Auto replay last valid state"),
                  onChanged: (v) => setState(() => autoReplayLastValid = v),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text("Annuler"),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _runFuzz(
                    step: step,
                    byteIndex: byteIndex,
                    minVal: minVal,
                    maxVal: maxVal,
                    delayMs: delayMs,
                    useBoundaryValues: useBoundaryValues,
                    useBitFlips: useBitFlips,
                    testPayloadSizes: testPayloadSizes,
                    stopOnDisconnect: stopOnDisconnect,
                    stopOnNotifyAnomaly: stopOnNotifyAnomaly,
                    stopOnTimeout: stopOnTimeout,
                    timeoutMs: timeoutMs,
                    autoReplayLastValid: autoReplayLastValid,
                  );
                },
                child: const Text("Lancer"),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _runFuzz({
  required BleScriptStep step,
  required int byteIndex,
  required int minVal,
  required int maxVal,
  required int delayMs,
  bool useBoundaryValues = true,
  bool useBitFlips = true,
  bool testPayloadSizes = true,
  bool stopOnDisconnect = true,
  bool stopOnNotifyAnomaly = true,
  bool stopOnTimeout = true,
  int timeoutMs = 500,
  bool autoReplayLastValid = true,
}) async {
  if (minVal > maxVal) {
    final tmp = minVal;
    minVal = maxVal;
    maxVal = tmp;
  }

  final base = List<int>.from(step.value);
  final targetKey = _charKey(step.serviceId, step.characteristicId);
  List<int>? lastValidNotify = _lastNotifiedValue[targetKey];
  List<int>? lastValidPayload;

  bool isDisconnected(DeviceConnectionState? state) {
    return state == null ||
        state == DeviceConnectionState.disconnected ||
        state == DeviceConnectionState.disconnecting;
  }

  bool notifyLooksIncoherent(List<int>? before, List<int>? after) {
    if (before == null) return false;
    if (after == null) return true;
    if (after.isEmpty) return true;
    final lenDiff = (after.length - before.length).abs();
    return lenDiff > 8;
  }

  if (byteIndex < 0 || byteIndex >= base.length) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Index $byteIndex hors limites (0..${base.length - 1})")),
    );
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        "Fuzz byte[$byteIndex] de 0x${minVal.toRadixString(16)} à 0x${maxVal.toRadixString(16)}...",
      ),
    ),
  );

  final payloads = <List<int>>[];
  void addPayload(List<int> payload) {
    payloads.add(List<int>.from(payload));
  }

  for (var b = minVal; b <= maxVal; b++) {
    final mutated = List<int>.from(base);
    mutated[byteIndex] = b;
    addPayload(mutated);
  }

  if (useBoundaryValues) {
    for (final boundary in [0x00, 0x7F, 0x80, 0xFF]) {
      final mutated = List<int>.from(base);
      mutated[byteIndex] = boundary.clamp(0, 0xFF).toInt();
      addPayload(mutated);
    }
  }

  if (useBitFlips) {
    for (final mask in [1, 2, 4, 8, 16, 32, 64, 128]) {
      final mutated = List<int>.from(base);
      mutated[byteIndex] = (base[byteIndex] ^ mask) & 0xFF;
      addPayload(mutated);
    }
  }

  if (testPayloadSizes) {
    if (base.length > 1) {
      addPayload(base.sublist(0, base.length - 1));
    }
    addPayload([...base, 0x00]);
    addPayload([...base, 0xFF, 0xFF]);
  }

  final uniquePayloads = <String, List<int>>{};
  for (final payload in payloads) {
    uniquePayloads[payload.join(',')] = payload;
  }

  String? stopReason;

  for (final mutated in uniquePayloads.values) {
    try {
      final writeFuture = widget.ble.writeRawCharacteristic(
        deviceId: widget.device.id,
        serviceId: step.serviceId,
        characteristicId: step.characteristicId,
        value: mutated,
        withResponse: true,
      );

      if (stopOnTimeout) {
        await writeFuture.timeout(Duration(milliseconds: timeoutMs));
      } else {
        await writeFuture;
      }

      lastValidPayload = mutated;
    } on TimeoutException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Timeout fuzz: $e"),
        ),
      );
      stopReason = "timeout";
      break;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Erreur fuzz avec payload ${mutated.length} bytes: $e",
          ),
        ),
      );
      stopReason = "exception";
      break;
    }

    if (delayMs > 0) {
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    if (!mounted) return;

    if (stopOnDisconnect && isDisconnected(_lastConnectionState)) {
      stopReason = "device disconnect";
      break;
    }

    if (stopOnNotifyAnomaly) {
      final newNotify = _lastNotifiedValue[targetKey];
      if (notifyLooksIncoherent(lastValidNotify, newNotify)) {
        stopReason = "notify incohérente";
        break;
      }
      if (newNotify != null) {
        lastValidNotify = newNotify;
      }
    }
  }

  if (!mounted) return;

  if (autoReplayLastValid && stopReason != null && lastValidPayload != null) {
    try {
      await widget.ble.writeRawCharacteristic(
        deviceId: widget.device.id,
        serviceId: step.serviceId,
        characteristicId: step.characteristicId,
        value: lastValidPayload!,
        withResponse: true,
      );
    } catch (_) {
      // Ignore replay errors
    }
  }

  final message = stopReason == null
      ? "Fuzz terminé."
      : "Fuzz stoppé (${stopReason}).";

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

Widget _buildInfoCard(DiscoveredDevice d) {
  return Card(
    elevation: 2,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Informations device",
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text("ID : ${d.id}"),
          Text("RSSI initial : ${d.rssi} dBm"),
          if (_deviceNameValue != null)
            Text("Nom (0x2A00) : $_deviceNameValue"),
          const SizedBox(height: 8),
          Text(
            "Statut : $_connectionStatus",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

Widget _buildActionsRow() {
  final hasServices = _discoveredServices.isNotEmpty;

  return Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      ElevatedButton.icon(
        onPressed: _onConnectPressed,
        icon: const Icon(Icons.link),
        label: const Text("Connect"),
      ),
      OutlinedButton.icon(
        onPressed: _onDisconnectPressed,
        icon: const Icon(Icons.link_off),
        label: const Text("Disconnect"),
      ),
      OutlinedButton.icon(
        onPressed: _showReplayDialog,
        icon: const Icon(Icons.play_arrow),
        label: const Text("Replay"),
      ),
      OutlinedButton.icon(
        onPressed: _showFuzzDialog,
        icon: const Icon(Icons.bolt),
        label: const Text("Fuzz"),
      ),
      if (hasServices)
        TextButton.icon(
          onPressed: _toggleAllNotifications,
          icon: Icon(
            _anyNotificationEnabled
                ? Icons.notifications_off
                : Icons.notifications_active,
          ),
          label: Text(
            _anyNotificationEnabled ? "Stop notify" : "Notify all",
          ),
        ),
    ],
  );
}

Widget _buildGattList() {
  if (_discoveredServices.isEmpty) {
    return const Center(child: Text("Aucun service pour l’instant."));
  }

  return ListView.builder(
    itemCount: _discoveredServices.length,
    itemBuilder: (context, index) {
      final service = _discoveredServices[index];
      final serviceUuid = service.serviceId.toString();
      final serviceName = GattDefs.serviceName(serviceUuid);

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                serviceName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                serviceUuid,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              if (service.characteristics.isNotEmpty)
                const Text(
                  "Characteristics",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ...service.characteristics.map(
                (charac) => _buildCharacteristicTile(service, charac),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildCharacteristicTile(
  DiscoveredService service,
  DiscoveredCharacteristic charac,
) {
  final key = _charKey(service.serviceId, charac.characteristicId);
  final notified = _notifySubs.containsKey(key);
  final last = _lastNotifiedValue[key];
  final vulnReasons = _computeVulnHeuristics(service, charac);

  final charUuid = charac.characteristicId.toString();
  final charName = GattDefs.characteristicName(charUuid);

  String lastHex = "";
  String lastAscii = "";
  if (last != null) {
    lastHex = last.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    lastAscii = String.fromCharCodes(last);
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          charName,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              charUuid,
              style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                if (charac.isReadable)
                  Chip(
                    label: const Text("R"),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (charac.isWritableWithResponse ||
                    charac.isWritableWithoutResponse)
                  Chip(
                    label: const Text("W"),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (charac.isNotifiable)
                  Chip(
                    label: const Text("N"),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (vulnReasons.isNotEmpty)
                  Chip(
                    label: const Text('⚠️ potentially vulnerable'),
                    backgroundColor: Colors.orange.shade100,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (charac.isReadable)
              IconButton(
                icon: const Icon(Icons.info),
                onPressed: () =>
                    _onReadCharacteristic(service.serviceId, charac.characteristicId),
              ),
            if (charac.isWritableWithResponse ||
                charac.isWritableWithoutResponse)
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _showWriteDialog(service, charac),
              ),
            if (charac.isNotifiable)
              IconButton(
                icon: Icon(
                  notified
                      ? Icons.notifications_active
                      : Icons.notifications,
                ),
                onPressed: () => _toggleNotify(service, charac),
              ),
          ],
        ),
      ),
      if (last != null)
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Dernière notif (bytes): $last"),
              Text("Hex: $lastHex"),
              Text("ASCII: $lastAscii"),
            ],
          ),
        ),
      if (vulnReasons.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: vulnReasons
                .map(
                  (reason) => Text('• $reason'),
                )
                .toList(),
          ),
        ),
      const Divider(height: 1),
    ],
  );
}

@override
Widget build(BuildContext context) {
  final d = widget.device;

  return Scaffold(
    appBar: AppBar(
      title: Text(
        d.name.isNotEmpty ? d.name : d.id,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildInfoCard(d),
          const SizedBox(height: 12),
          _buildActionsRow(),
          const SizedBox(height: 12),
          Expanded(child: _buildGattList()),
        ],
      ),
    ),
  );
}

}
