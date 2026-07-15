class Landmark {
  final int id;
  final String name;
  final String category;
  final String? description;
  final double? latitude;
  final double? longitude;

  Landmark({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.latitude,
    this.longitude,
  });

  /// Built to be defensive: the backend/db work (Maria/Josephine) may still be
  /// missing lat/lng for some landmarks, or send them as strings. This must
  /// never throw — a bad landmark should just have null coordinates, not
  /// crash the whole list (see Ritah's QA checklist).
  factory Landmark.fromJson(Map<String, dynamic> json) {
    return Landmark(
      id: _parseInt(json['id']) ?? 0,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Unnamed landmark',
      category: (json['category'] as String?) ?? 'Uncategorized',
      description: json['description'] as String?,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
    );
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Use this before plotting a marker — never assume lat/lng exist.
  bool get hasCoordinates => latitude != null && longitude != null;
}
