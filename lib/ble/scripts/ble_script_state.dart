import 'package:firsdt_app/ble/scripts/ble_scripts_step.dart';
import 'package:flutter/foundation.dart';

class BleScriptState extends ChangeNotifier {
  final List<BleScriptStep> _steps = [];

  List<BleScriptStep> get steps => List.unmodifiable(_steps);

  bool get isEmpty => _steps.isEmpty;

  void addStep(BleScriptStep step) {
    _steps.add(step);
    notifyListeners();
  }

  void clear() {
    _steps.clear();
    notifyListeners();
  }

}
