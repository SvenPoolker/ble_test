import 'package:firsdt_app/ble/pages/ble_log_page.dart';
import 'package:flutter/material.dart';
import 'package:firsdt_app/main.dart';
import 'package:firsdt_app/features/items/pages/list_page.dart';
import 'package:firsdt_app/ble/pages/ble_scan_page.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;

  const AppBottomNav({super.key, required this.currentIndex});

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return;

    late final Widget target;

    switch (index) {
      case 0:
        target = const MyHomePage(title: 'My first Flutter App');
        break;
      case 1:
        target = const ListPage();
        break;
      case 2:
        target = const BleScanPage();
        break;
      case 3:
        target = const BleLogPage();
        break;
      default:
        return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => target),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _onItemTapped(context, index),
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Liste'),
        BottomNavigationBarItem(icon: Icon(Icons.bluetooth_searching), label: 'Scan BLE'),
        BottomNavigationBarItem(icon: Icon(Icons.storage ), label: 'Log BLE'),
      ],
    );
  }
}
