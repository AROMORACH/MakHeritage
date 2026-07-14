import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/landmark.dart';
import '../services/landmark_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LandmarkService _service = LandmarkService();
  late Future<List<Landmark>> _future;

  // Approximate center of Makerere University, Kampala.
  static const LatLng _makerereCenter = LatLng(0.3315, 32.5675);

  @override
  void initState() {
    super.initState();
    _future = _service.fetchLandmarks();
  }

  void _retry() {
    setState(() {
      _future = _service.fetchLandmarks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Landmark>>(
      future: _future,
      builder: (context, snapshot) {
        // Loading state — spinner while the API responds.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // Error state — network failure, 404, bad JSON, etc. No red screen.
        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString(), onRetry: _retry);
        }

        final landmarks = snapshot.data ?? [];

        // Only plot landmarks that actually have coordinates.
        final markers = landmarks
            .where((l) => l.hasCoordinates)
            .map(
              (l) => Marker(
                point: LatLng(l.latitude!, l.longitude!),
                width: 44,
                height: 44,
                child: Tooltip(
                  message: l.name,
                  child: const Icon(
                    Icons.location_on,
                    color: Color(0xFFE5A93C),
                    size: 38,
                  ),
                ),
              ),
            )
            .toList();

        return Stack(
          children: [
            FlutterMap(
              options: const MapOptions(
                initialCenter: _makerereCenter,
                initialZoom: 16,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.makheritage.app',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
            if (landmarks.isNotEmpty && markers.isEmpty)
              // Data loaded fine, but nothing had coordinates yet
              // (e.g. Josephine/Maria haven't finished seeding lat/lng).
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _InfoBanner(
                  text:
                      '${landmarks.length} landmarks loaded, but none have coordinates yet.',
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}
