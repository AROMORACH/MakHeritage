import 'package:flutter/material.dart';

void main() {
  runApp(const MakHeritageApp());
}

class MakHeritageApp extends StatelessWidget {
  const MakHeritageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MakHeritage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006633), // Makerere Green
          primary: const Color(0xFF006633),
          secondary: const Color(0xFFE5A93C), // Gold
        ),
      ),
      home: const LandmarkListStagingScreen(),
    );
  }
}

class LandmarkListStagingScreen extends StatelessWidget {
  const LandmarkListStagingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = ['All', 'College', 'Hall', 'Spiritual', 'Infrastructure', 'Gate'];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MakHeritage • Week 1 Staging', 
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)
        ),
        backgroundColor: const Color(0xFF006633),
      ),
      body: Column(
        children: [
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: ChoiceChip(
                  label: Text(categories[index]),
                  selected: index == 0,
                ),
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                '36 Production Nodes Initialised\nReady for Week 2 backend connection.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}