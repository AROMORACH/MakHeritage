import 'package:flutter/material.dart';
import 'screens/map_view_screen.dart';
import 'widgets/nav_bar.dart';

void main() {
  runApp(const TourApp());
}

class TourApp extends StatelessWidget {
  const TourApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mak Heritage',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepOrange,
        useMaterial3: true,
      ),
      home: const RootShell(),
    );
  }
}

/// Holds the bottom-nav selected index and swaps between screens.
/// "Landmarks" and "About" are stub placeholders for now — flesh out
/// as separate screens later, same pattern as MapViewScreen.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const _screens = [
    MapViewScreen(),
    Center(child: Text('Landmarks list — TODO')),
    Center(child: Text('About — TODO')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mak Heritage')),
      body: _screens[_index],
      bottomNavigationBar: AppNavBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}