import 'package:firsdt_app/ble/log/ble_log_state.dart';
import 'package:firsdt_app/ble/playbooks/ble_playbook.dart';
import 'package:firsdt_app/ble/playbooks/ble_playbook_runner.dart';
import 'package:firsdt_app/ble/playbooks/ble_playbook_state.dart';
import 'package:firsdt_app/ble/services/ble_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:provider/provider.dart';

class BlePlaybookPage extends StatefulWidget {
  const BlePlaybookPage({super.key});

  @override
  State<BlePlaybookPage> createState() => _BlePlaybookPageState();
}

class _BlePlaybookPageState extends State<BlePlaybookPage> {
  final BleService _ble = BleService();
  final TextEditingController _jsonController = TextEditingController();

  @override
  void dispose() {
    _jsonController.dispose();
    super.dispose();
  }

  BlePlaybook _buildSamplePlaybook() {
    const targetDevice = 'AA:BB:CC:DD:EE:FF';
    final service = Uuid.parse('0000180a-0000-1000-8000-00805f9b34fb');
    final characteristic = Uuid.parse('00002a29-0000-1000-8000-00805f9b34fb');
    final control = Uuid.parse('00002a24-0000-1000-8000-00805f9b34fb');

    return BlePlaybook(
      name: 'Playbook connect/write/notify',
      description:
          "Connect → write 'A' → wait 200ms → write 'B' → listen notify until payload contains X then send Y",
      steps: [
        BlePlaybookStep.connect(targetDevice),
        BlePlaybookStep.write(
          deviceId: targetDevice,
          serviceId: service,
          characteristicId: characteristic,
          payload: 'A'.codeUnits,
        ),
        BlePlaybookStep.wait(const Duration(milliseconds: 200)),
        BlePlaybookStep.write(
          deviceId: targetDevice,
          serviceId: service,
          characteristicId: control,
          payload: 'B'.codeUnits,
        ),
        BlePlaybookStep.waitNotify(
          deviceId: targetDevice,
          serviceId: service,
          characteristicId: control,
          expectContains: '58', // 'X' in hex
          onMatchWrite: 'Y'.codeUnits,
          maxAttempts: 10,
        ),
      ],
    );
  }

  BlePlaybook _buildBrightnessPlaybook() {
    const targetDevice = 'AA:BB:CC:DD:EE:11';
    final lightingService = Uuid.parse('0000fff0-0000-1000-8000-00805f9b34fb');
    final brightnessCharacteristic = Uuid.parse('0000fff1-0000-1000-8000-00805f9b34fb');

    return BlePlaybook(
      name: 'Luminosité à 100%',
      description:
          "Connexion à l'éclairage → écriture d'une valeur de luminosité de 100 (0x64).",
      steps: [
        BlePlaybookStep.connect(targetDevice),
        BlePlaybookStep.write(
          deviceId: targetDevice,
          serviceId: lightingService,
          characteristicId: brightnessCharacteristic,
          payload: const [0x64],
        ),
      ],
    );
  }

  Future<void> _runPlaybook(BlePlaybook playbook) async {
    final runner = BlePlaybookRunner(
      ble: _ble,
      logState: context.read<BleLogState>(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exécution de ${playbook.name}...')),
    );

    final result = await runner.run(playbook);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _importDialog() async {
    _jsonController.text = '';
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Importer des playbooks (JSON)'),
          content: TextField(
            controller: _jsonController,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'Collez ici le JSON exporté',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                try {
                  context.read<BlePlaybookState>().importFromJson(_jsonController.text);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Playbooks importés !')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur import: $e')),
                  );
                }
              },
              child: const Text('Importer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportDialog() async {
    final json = context.read<BlePlaybookState>().exportToJson();
    _jsonController.text = json;
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('JSON des playbooks'),
          content: TextField(
            controller: _jsonController,
            maxLines: 12,
            readOnly: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playbookState = context.watch<BlePlaybookState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Playbooks'),
        actions: [
          IconButton(
            onPressed: _exportDialog,
            icon: const Icon(Icons.ios_share),
            tooltip: 'Exporter JSON',
          ),
          IconButton(
            onPressed: _importDialog,
            icon: const Icon(Icons.download),
            tooltip: 'Importer JSON',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enchaînez des actions (connexion, écritures, attentes, notifications) et partagez-les en JSON.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    playbookState.addSample(_buildSamplePlaybook());
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Ajouter le playbook connect/notify'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    playbookState.addSample(_buildBrightnessPlaybook());
                  },
                  icon: const Icon(Icons.light_mode_outlined),
                  label: const Text('Playbook luminosité à 100% (JSON prêt)'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: playbookState.playbooks.isEmpty
                  ? const Center(
                      child: Text('Aucun playbook. Importez un JSON ou créez un exemple.'),
                    )
                  : ListView.builder(
                      itemCount: playbookState.playbooks.length,
                      itemBuilder: (context, index) {
                        final pb = playbookState.playbooks[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        pb.name,
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => playbookState.removeByName(pb.name),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                Text(pb.description),
                                const SizedBox(height: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: pb.steps
                                      .map((s) => Text('• ${s.describe()}'))
                                      .toList(growable: false),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () => _runPlaybook(pb),
                                      icon: const Icon(Icons.play_circle_fill),
                                      label: const Text('Lancer'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: _exportDialog,
                                      icon: const Icon(Icons.ios_share),
                                      label: const Text('Exporter'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
