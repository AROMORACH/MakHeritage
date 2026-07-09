import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/landmark.dart';
import '../widgets/landmark_card.dart';

/// Main map screen. Loads mock landmark data for now — swap
/// [_loadLandmarks] to hit the real API/DB once Maria + Joshua's
/// backend is ready.
class MapViewScreen extends StatefulWidget {
  const MapViewScreen({super.key});

  @override
  State<MapViewScreen> createState() => _MapViewScreenState();
}

class _MapViewScreenState extends State<MapViewScreen> {
  final MapController _mapController = MapController();
  List<Landmark> _landmarks = [];
  bool _loading = true;

  // Default center: Kampala. Adjust to your tour region.
  static const LatLng _initialCenter = LatLng(0.3163, 32.5822);

  @override
  void initState() {
    super.initState();
    _loadLandmarks();
  }

  Future<void> _loadLandmarks() async {
    final raw = await rootBundle.loadString('assets/data/landmarks_mock.json');
    final List<dynamic> decoded = jsonDecode(raw);
    setState(() {
      _landmarks = decoded.map((e) => Landmark.fromJson(e)).toList();
      _loading = false;
    });
  }

  void _focusOn(Landmark landmark) {
    _mapController.move(LatLng(landmark.latitude, landmark.longitude), 16);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: const MapOptions(
            initialCenter: _initialCenter,
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              // OpenStreetMap tiles — free, no API key. Replace urlTemplate
              // if the team wants a different tile provider later.
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.makheritage',
            ),
            MarkerLayer(
              markers: _landmarks
                  .map(
                    (landmark) => Marker(
                      point: LatLng(landmark.latitude, landmark.longitude),
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _focusOn(landmark),
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 36,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        // Bottom scroll list of landmark cards, draggable up from
        // the bottom edge of the map.
        DraggableScrollableSheet(
          initialChildSize: 0.18,
          minChildSize: 0.12,
          maxChildSize: 0.6,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8),
                ],
              ),
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.only(top: 12),
                itemCount: _landmarks.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }
                  final landmark = _landmarks[index - 1];
                  return LandmarkCard(
                    landmark: landmark,
                    onTap: () => _focusOn(landmark),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
