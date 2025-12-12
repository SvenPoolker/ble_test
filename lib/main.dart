import 'package:firsdt_app/ble/log/ble_log_state.dart';
import 'package:firsdt_app/ble/pages/ble_log_page.dart';
import 'package:firsdt_app/ble/pages/ble_scan_page.dart';
import 'package:firsdt_app/ble/scripts/ble_script_state.dart';
import 'package:firsdt_app/core/theme/theme_state.dart';
import 'package:firsdt_app/features/items/pages/list_page.dart';
import 'package:firsdt_app/features/items/pages/second_page.dart';
import 'package:firsdt_app/features/items/state/items_state.dart';
import 'package:firsdt_app/utils/company_identifiers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firsdt_app/core/branding/animated_splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CompanyIdentifiers.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ItemsState()),
        ChangeNotifierProvider(create: (_) => BleLogState()),
        ChangeNotifierProvider(create: (_) => ThemeState()),
        ChangeNotifierProvider(create: (_) => BleScriptState()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeState = context.watch<ThemeState>();

    return MaterialApp(
      title: 'BLE Pentest Lab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: themeState.themeMode,
      home: AnimatedSplashPage(
        minDuration: const Duration(milliseconds: 900),
        next: const MyHomePage(title: 'BLE Pentest Lab'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  int _selectedIndex = 0;

  void _incrementCounter() {
    setState(() {
      _counter += 2;
    });
  }

  void _resetCounter() {
    setState(() {
      _counter = 0;
    });
  }

  Widget _buildHomeTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Tu as appuyé sur le bouton tant de fois :'),
          const SizedBox(height: 8),
          Text(
            '$_counter',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _resetCounter,
            child: const Text("Reset"),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SecondPage(compteur: _counter),
                ),
              );
            },
            child: const Text('Aller à la page 2'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return const ListPage();
      case 2:
        return const BleScanPage();
      case 3:
        return const BleLogPage();
      default:
        return _buildHomeTab();
    }
  }

  Widget? _buildFab() {
    // FAB seulement sur l’onglet Home
    if (_selectedIndex != 0) return null;
    return FloatingActionButton(
      onPressed: _incrementCounter,
      tooltip: 'Increment',
      child: const Icon(Icons.add),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = context.watch<ThemeState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(
              themeState.isDark ? Icons.dark_mode : Icons.light_mode,
            ),
            onPressed: () {
              context.read<ThemeState>().toggle();
            },
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _buildFab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list),
            label: 'Liste',
          ),
          NavigationDestination(
            icon: Icon(Icons.bluetooth_searching_outlined),
            selectedIcon: Icon(Icons.bluetooth_searching),
            label: 'Scan BLE',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: 'Logs',
          ),
        ],
      ),
    );
  }
}
