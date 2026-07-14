import 'package:flutter/material.dart';
import '../models/landmark.dart';
import '../services/landmark_service.dart';
import '../widgets/landmark_card.dart';

class LandmarkListScreen extends StatefulWidget {
  const LandmarkListScreen({super.key});

  @override
  State<LandmarkListScreen> createState() => _LandmarkListScreenState();
}

class _LandmarkListScreenState extends State<LandmarkListScreen> {
  final LandmarkService _service = LandmarkService();
  late Future<List<Landmark>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.fetchLandmarks();
  }

  Future<void> _retry() async {
    setState(() {
      _future = _service.fetchLandmarks();
    });
    await _future.catchError((_) => <Landmark>[]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Landmark>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _future = _service.fetchLandmarks();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final landmarks = snapshot.data ?? [];

        if (landmarks.isEmpty) {
          return const Center(child: Text('No landmarks found.'));
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _future = _service.fetchLandmarks();
            });
            await _future.catchError((_) => <Landmark>[]);
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: landmarks.length,
            itemBuilder: (context, index) => LandmarkCard(landmark: landmarks[index]),
          ),
        );
      },
    );
  }
}
