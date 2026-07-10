class Landmark {
  final String id;
  final String name;
  final int foundationYear; // Renamed to align with database
  final String category;
  final String description;
  final double latitude;
  final double longitude;
  final String? imageUrl;   // Maps from image_url

  const Landmark({
    required this.id,
    required this.name,
    required this.foundationYear,
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
      foundationYear: json['foundation_year'] as int, // Fixed key match
      category: json['category'] as String,
      description: json['description'] as String? ?? '',
      latitude: (json['latitude'] as num? ?? 0.3163).toDouble(),   // Added fallback safety
      longitude: (json['longitude'] as num? ?? 32.5822).toDouble(), // Added fallback safety
      imageUrl: json['image_url'] as String?, // Fixed key match
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'foundation_year': foundationYear,
        'category': category,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'image_url': imageUrl,
      };
}