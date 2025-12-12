import 'package:flutter/foundation.dart';
import 'ble_log_entry.dart';

class BleLogState extends ChangeNotifier {
  final List<BleLogEntry> _entries = [];

  List<BleLogEntry> get entries => List.unmodifiable(_entries);

  void add(BleLogEntry entry) {
    _entries.add(entry);
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    notifyListeners();
  }

  List<Map<String, dynamic>> toJsonList() =>
      _entries.map((e) => e.toJson()).toList();
}
