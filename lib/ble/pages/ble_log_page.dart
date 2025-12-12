import 'package:firsdt_app/ble/log/ble_log_entry.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../log/ble_log_state.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BleLogPage extends StatefulWidget {
  const BleLogPage({super.key});

  @override
  State<BleLogPage> createState() => _BleLogPageState();
}

class _BleLogPageState extends State<BleLogPage> {
  BleLogType? _typeFilter;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  Future<File> _exportJsonFile(BuildContext context) async {
    final logState = context.read<BleLogState>();
    final jsonList = logState.toJsonList();
    final jsonString = jsonEncode(jsonList);

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      "${dir.path}/ble_log_${DateTime.now().toIso8601String()}.json",
    );
    await file.writeAsString(jsonString);
    return file;
  }

  String _logsToCsv(BleLogState logState) {
    final buffer = StringBuffer();
    buffer.writeln("timestamp,type,deviceId,deviceName,message,rawHex");

    for (final e in logState.entries) {
      final hex = e.rawValue == null
          ? ""
          : e.rawValue!
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join(' ');

      // Échapper les guillemets dans le message
      final safeMsg = e.message.replaceAll('"', '""');

      buffer.writeln(
        '"${e.timestamp.toIso8601String()}",'
        '"${e.type.name}",'
        '"${e.deviceId}",'
        '"${e.deviceName ?? ''}",'
        '"$safeMsg",'
        '"$hex"',
      );
    }

    return buffer.toString();
  }

  Future<File> _exportCsvFile(BuildContext context) async {
    final logState = context.read<BleLogState>();
    final csv = _logsToCsv(logState);

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      "${dir.path}/ble_log_${DateTime.now().toIso8601String()}.csv",
    );
    await file.writeAsString(csv);
    return file;
  }

  Widget _buildFilters(BleLogState logState) {
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
            Row(
              children: [
                const Text("Type: "),
                const SizedBox(width: 8),
                DropdownButton<BleLogType?>(
                  value: _typeFilter,
                  hint: const Text("Tous"),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text("Tous"),
                    ),
                    ...BleLogType.values.map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _typeFilter = value;
                    });
                  },
                ),
                const Spacer(),
                Text(
                  "${logState.entries.length} logs",
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: "Recherche (message / device)",
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildLogTile(BleLogEntry e, String hex) {
  final typeColor = switch (e.type) {
    BleLogType.connect => Colors.green,
    BleLogType.disconnect => Colors.orange,
    BleLogType.error => Colors.red,
    BleLogType.write => Colors.blue,
    BleLogType.read => Colors.teal,
    BleLogType.notify => Colors.purple,
    BleLogType.advert => Colors.grey,
  };

  return ListTile(
    dense: true,
    leading: CircleAvatar(
      radius: 14,
      backgroundColor: typeColor.withOpacity(0.1),
      child: Icon(
        Icons.bolt,
        size: 16,
        color: typeColor,
      ),
    ),
    title: Text(
      "[${e.type.name}] ${e.message}",
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          e.timestamp.toIso8601String(),
          style: const TextStyle(
            fontSize: 11,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          "${e.deviceName ?? ''} (${e.deviceId})",
          style: const TextStyle(fontSize: 11),
        ),
        if (hex.isNotEmpty)
          Text(
            "Hex: $hex",
            style: const TextStyle(fontSize: 11),
          ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final logState = context.watch<BleLogState>();
    final entries = logState.entries;

    final filtered = entries.where((e) {
      if (_typeFilter != null && e.type != _typeFilter) return false;

      final q = _searchController.text.trim().toLowerCase();
      if (q.isNotEmpty) {
        final blob = "${e.message} ${e.deviceId} ${e.deviceName ?? ''}"
            .toLowerCase();
        if (!blob.contains(q)) return false;
      }

      return true;
    }).toList();
    return Scaffold(
      appBar: AppBar(
      title: const Text("BLE Log"),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete),
          tooltip: "Effacer les logs",
          onPressed: () => logState.clear(),
        ),
        IconButton(
          tooltip: "Export JSON & share",
          icon: const Icon(Icons.data_object),
          onPressed: () async {
            try {
              final file = await _exportJsonFile(context);
              await Share.shareXFiles(
                [XFile(file.path)],
                text: "BLE log JSON",
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Erreur export JSON: $e")),
              );
            }
          },
        ),
        IconButton(
          tooltip: "Export CSV & share",
          icon: const Icon(Icons.file_present),
          onPressed: () async {
            try {
              final file = await _exportCsvFile(context);
              await Share.shareXFiles(
                [XFile(file.path)],
                text: "BLE log CSV",
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Erreur export CSV: $e")),
              );
            }
          },
        ),
      ],
    ),
    body: Column(
    children: [
      _buildFilters(logState),
      const Divider(height: 1),
      Expanded(
        child: filtered.isEmpty
            ? const Center(child: Text("Aucun log avec ces filtres"))
            : ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final e = filtered[index];
                  final hex = e.rawValue == null
                      ? ""
                      : e.rawValue!
                          .map((b) => b.toRadixString(16).padLeft(2, '0'))
                          .join(' ');

                  return _buildLogTile(e, hex);
                },
              ),
      ),
    ],
  ),
    );
  }

}
