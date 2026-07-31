class Landmark {
  final int id;
  final String name;
  final String category;
  final String? description;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;

  Landmark({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    this.latitude,
    this.longitude,
    this.imageUrl,
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
      imageUrl: json['image_url'] as String?,
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

  /// Returns the relative asset path, network URL, or local file path to the landmark's picture if available.
  String? get imageAssetPath {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return imageUrl;
    }
    final lowerName = name.toLowerCase();
    if (lowerName.contains('ivory tower') || lowerName.contains('main building') || lowerName.contains('main admin')) {
      return 'assets/data/landmarks_pictures/The main building.jpg';
    } else if (lowerName.contains('freedom square')) {
      return 'assets/data/landmarks_pictures/Freedom square.jpg';
    } else if (lowerName.contains('main library') || lowerName.contains('library')) {
      return 'assets/data/landmarks_pictures/Makerere University Library.jpg';
    } else if (lowerName.contains('senate')) {
      return 'assets/data/landmarks_pictures/Senate Building.jpg';
    } else if (lowerName.contains('lumumba')) {
      return 'assets/data/landmarks_pictures/Lumumba hall.jpg';
    } else if (lowerName.contains('mitchell')) {
      return 'assets/data/landmarks_pictures/Mitchell hall.png';
    } else if (lowerName.contains('livingstone')) {
      return 'assets/data/landmarks_pictures/Livingstone Hall.jpeg';
    } else if (lowerName.contains('africa hall')) {
      return 'assets/data/landmarks_pictures/Africa Hall.jpeg';
    } else if (lowerName.contains('nkrumah')) {
      return 'assets/data/landmarks_pictures/Nkrumah hall.jpg';
    } else if (lowerName.contains('nsibirwa')) {
      return 'assets/data/landmarks_pictures/Nsibirwa hall.jpg';
    } else if (lowerName.contains('dag hammarskj')) {
      return 'assets/data/landmarks_pictures/Dag Hammarskjold Hall.jpg';
    } else if (lowerName.contains('cocis') || lowerName.contains('computing')) {
      return 'assets/data/landmarks_pictures/CoCIS.jpeg';
    } else if (lowerName.contains('cedat') || lowerName.contains('engineering')) {
      return 'assets/data/landmarks_pictures/CEDAT.jpeg';
    } else if (lowerName.contains('mtsifa') || lowerName.contains('industrial and fine art')) {
      return 'assets/data/landmarks_pictures/MTSIFA.jpeg';
    } else if (lowerName.contains('school of law') || lowerName.contains('law')) {
      return 'assets/data/landmarks_pictures/School of Law.jpeg';
    } else if (lowerName.contains('cobams') || lowerName.contains('business')) {
      return 'assets/data/landmarks_pictures/CoBAMS.jpeg';
    } else if (lowerName.contains('chuss') || lowerName.contains('humanities')) {
      return 'assets/data/landmarks_pictures/CHUSS.jpeg';
    } else if (lowerName.contains('conas') || lowerName.contains('natural sciences')) {
      return 'assets/data/landmarks_pictures/CoNAS.jpeg';
    } else if (lowerName.contains('cees') || lowerName.contains('education')) {
      return 'assets/data/landmarks_pictures/CEES.jpeg';
    } else if (lowerName.contains('covab') || lowerName.contains('veterinary')) {
      return 'assets/data/landmarks_pictures/CoVAB.jpeg';
    } else if (lowerName.contains('st. francis')) {
      return 'assets/data/landmarks_pictures/St. Francis Chapel.jpeg';
    } else if (lowerName.contains('st. augustine')) {
      return 'assets/data/landmarks_pictures/St. Augustine Chapel.jpeg';
    } else if (lowerName.contains('mosque')) {
      return 'assets/data/landmarks_pictures/Mosque.jpeg';
    } else if (lowerName.contains('hospital')) {
      return 'assets/data/landmarks_pictures/Makerere University Hospital.png';
    } else if (lowerName.contains('swimming pool') || lowerName.contains('sports grounds')) {
      return 'assets/data/landmarks_pictures/Makerere swimming pool.jpg';
    } else if (lowerName.contains('guest house')) {
      return 'assets/data/landmarks_pictures/Makerere University Guest House.png';
    } else if (lowerName.contains('main gate')) {
      return 'assets/data/landmarks_pictures/Makerere University Main Gate.jpg';
    } else if (lowerName.contains('ctf ii') || lowerName.contains('ctf2') || lowerName.contains('central teaching facility ii')) {
      return 'assets/data/landmarks_pictures/CTF II.jpg';
    } else if (lowerName.contains('ctf i') || lowerName.contains('ctf1') || lowerName.contains('central teaching facility i')) {
      return 'assets/data/landmarks_pictures/CTF1.webp';
    } else if (lowerName.contains('mary stuart')) {
      return 'assets/data/landmarks_pictures/Mary Stuart Hall.jpg';
    } else if (lowerName.contains('university hall')) {
      return 'assets/data/landmarks_pictures/University Hall.jpg';
    } else if (lowerName.contains('innovation hub')) {
      return 'assets/data/landmarks_pictures/MakerereInnovation Hub.jpg';
    } else if (lowerName.contains('printery')) {
      return 'assets/data/landmarks_pictures/University Printery.jpg';
    } else if (lowerName.contains('oval') || lowerName.contains('sports ground')) {
      return 'assets/data/landmarks_pictures/Main Sports Grounds.jpg';
    } else if (lowerName.contains('mastercard')) {
      return 'assets/data/landmarks_pictures/Mastercard.jpeg';
    } else if (lowerName.contains('caes') || lowerName.contains('agricultural')) {
      return 'assets/data/landmarks_pictures/College of Agricultural and Environmental Sciences.jpeg';
    } else if (lowerName.contains('lincoln')) {
      return 'assets/data/landmarks_pictures/Lincoln Flats.jpeg';
    } else if (lowerName.contains('western gate') || lowerName.contains('kikoni gate')) {
      return 'assets/data/landmarks_pictures/Western Gate.jpeg';
    }
    return null;
  }
}
