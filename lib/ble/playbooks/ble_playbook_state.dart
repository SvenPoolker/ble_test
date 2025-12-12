import 'dart:convert';

import 'package:firsdt_app/ble/playbooks/ble_playbook.dart';
import 'package:flutter/foundation.dart';

class BlePlaybookState extends ChangeNotifier {
  final List<BlePlaybook> _playbooks = [];

  List<BlePlaybook> get playbooks => List.unmodifiable(_playbooks);

  void upsert(BlePlaybook playbook) {
    final index = _playbooks.indexWhere((p) => p.name == playbook.name);
    if (index >= 0) {
      _playbooks[index] = playbook;
    } else {
      _playbooks.add(playbook);
    }
    notifyListeners();
  }

  void importFromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is List) {
      _playbooks
        ..clear()
        ..addAll(decoded.map((e) => BlePlaybook.fromJson(e as Map<String, dynamic>)));
    } else {
      throw const FormatException('Expected a JSON array of playbooks');
    }
    notifyListeners();
  }

  String exportToJson() {
    final data = _playbooks.map((e) => e.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  void addSample(BlePlaybook playbook) {
    upsert(playbook);
  }

  void removeByName(String name) {
    _playbooks.removeWhere((p) => p.name == name);
    notifyListeners();
  }
}
