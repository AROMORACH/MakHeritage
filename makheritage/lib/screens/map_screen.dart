import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/landmark.dart';
import '../services/landmark_service.dart';
import '../services/geofence_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final LandmarkService _service = LandmarkService();
  final GeofenceService _geofenceService = GeofenceService();
  late Future<List<Landmark>> _future;
  
  StreamSubscription<Position>? _positionStream;
  final Set<String> _triggeredLandmarks = {};

  // Approximate center of Makerere University, Kampala.
  static const LatLng _makerereCenter = LatLng(0.3315, 32.5675);

  @override
  void initState() {
    super.initState();
    _future = _service.fetchLandmarks().then((landmarks) {
      _startTracking(landmarks);
      return landmarks;
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _startTracking(List<Landmark> landmarks) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    }

    // 1. Force an immediate check right now
    try {
      Position currentPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      _geofenceService.checkProximity(currentPos, landmarks, (landmark) {
        if (!_triggeredLandmarks.contains(landmark.name)) {
          _triggeredLandmarks.add(landmark.name);
          _showLandmarkDetails(landmark, isProximity: true);
        }
      });
    } catch (e) {
      debugPrint("Could not get initial location: $e");
    }

    // 2. Listen for future movement
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high, 
      distanceFilter: 5, // Lowered to 5 metres for better sensitivity
    );
    
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      _geofenceService.checkProximity(position, landmarks, (landmark) {
        if (!_triggeredLandmarks.contains(landmark.name)) {
          _triggeredLandmarks.add(landmark.name);
          _showLandmarkDetails(landmark, isProximity: true);
        }
      });
    });
  }

  void _retry() {
    setState(() {
      _future = _service.fetchLandmarks().then((landmarks) {
        _startTracking(landmarks);
        return landmarks;
      });
    });
  }

  void _showLandmarkDetails(Landmark landmark, {bool isProximity = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isProximity)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "📍 You are nearby!",
                    style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
              Text(
                landmark.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "${landmark.category}",
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                landmark.description ?? "No description available.",
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
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
          return _ErrorState(message: snapshot.error.toString(), onRetry: _retry);
        }

        final landmarks = snapshot.data ?? [];

        final markers = landmarks
            .where((l) => l.hasCoordinates)
            .map(
              (l) => Marker(
                point: LatLng(l.latitude!, l.longitude!),
                width: 50,
                height: 50,
                child: GestureDetector(
                  onTap: () => _showLandmarkDetails(l),
                  child: const Tooltip(
                    message: "Tap to view",
                    child: Icon(
                      Icons.location_on,
                      color: Color(0xFFE5A93C),
                      size: 44,
                    ),
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
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _InfoBanner(
                  text: '${landmarks.length} landmarks loaded, but none have coordinates yet.',
                ),
              ),
            // Radar Button for Manual Proximity Scan
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton(
                backgroundColor: const Color(0xFFE5A93C),
                child: const Icon(Icons.radar, color: Colors.white),
                onPressed: () async {
                  try {
                    Position pos = await Geolocator.getCurrentPosition(
                      desiredAccuracy: LocationAccuracy.high,
                    );
                    
                    bool found = false;
                    _geofenceService.checkProximity(pos, landmarks, (landmark) {
                      found = true;
                      _showLandmarkDetails(landmark, isProximity: true);
                    });

                    if (!found && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No landmarks within 50 metres.')),
                      );
                    }
                  } catch (e) {
                    debugPrint("Location error: $e");
                  }
                },
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