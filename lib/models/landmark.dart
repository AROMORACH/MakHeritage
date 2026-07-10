/// Data model for a single historical landmark/tour stop.
///
/// This shape is a REASONABLE GUESS at what Josephine's data/landmarks.json
/// (Week 2 deliverable) will look like, based on Ritah's QA note about
/// checking for "missing years or category mismatches."
///
/// Once Josephine's real JSON schema lands, only this file and
/// `fromJson` need to change — the rest of the UI won't care.
class Landmark {
  final String id;
  final String name;
  final int year;
  final String category;
  final String description;
  final double latitude;
  final double longitude;
  final String? imageUrl;

  const Landmark({
    required this.id,
    required this.name,
    required this.year,
    required this.category,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.imageUrl,
  });

  factory Landmark.fromJson(Map<String, dynamic> json) {
    return Landmark(
      id: json['id'].toString(),
      name: json['name'] as String,
      year: json['year'] as int,
      category: json['category'] as String,
      description: json['description'] as String? ?? '',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'year': year,
        'category': category,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'imageUrl': imageUrl,
      };
}