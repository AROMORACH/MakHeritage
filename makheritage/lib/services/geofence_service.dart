import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/landmark.dart';

class GeofenceService {
  final Distance _distance = const Distance();
  final double thresholdInMeters = 50.0;

  void checkProximity(Position userPos, List<Landmark> landmarks, Function(Landmark) onTrigger) {
    for (var landmark in landmarks) {
      if (landmark.latitude == null || landmark.longitude == null) continue;

      final double dist = _distance.as(
        LengthUnit.Meter,
        LatLng(userPos.latitude, userPos.longitude),
        LatLng(landmark.latitude!, landmark.longitude!),
      );

      if (dist < thresholdInMeters) {
        onTrigger(landmark);
      }
    }
  }
}