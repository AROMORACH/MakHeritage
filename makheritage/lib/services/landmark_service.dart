import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/landmark.dart';

/// Thrown for any network/parsing failure so the UI can show one
/// consistent "couldn't load" state instead of crashing.
class LandmarkServiceException implements Exception {
  final String message;
  LandmarkServiceException(this.message);

  @override
  String toString() => message;
}

class LandmarkService {
  /// IMPORTANT — pick the right base URL for where you're running:
  ///  - Android emulator            -> 10.0.2.2
  ///  - iOS simulator / Chrome/web   -> 127.0.0.1
  ///  - Physical phone (e.g. your Samsung SM-A047F over Wi-Fi)
  ///                                 -> your PC's LAN IP, e.g. 192.168.1.42
  ///    (find it on Windows with `ipconfig`, look for IPv4 Address under
  ///    your Wi-Fi adapter — phone and PC must be on the same network)
  static const String baseUrl = 'http://10.216.6.32:5000';

  final http.Client _client;

  LandmarkService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Landmark>> fetchLandmarks({String? category}) async {
    final path = (category == null || category == 'All')
        ? '/api/landmarks'
        : '/api/landmarks/$category';
    final uri = Uri.parse('$baseUrl$path');

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is! List) {
          throw LandmarkServiceException('Unexpected response shape from API');
        }
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(Landmark.fromJson)
            .toList();
      } else if (response.statusCode == 404) {
        throw LandmarkServiceException('No landmarks found (404)');
      } else {
        throw LandmarkServiceException(
          'Server error (status ${response.statusCode})',
        );
      }
    } on SocketException {
      throw LandmarkServiceException(
        'Could not reach the API. Is the backend running on port 5000?',
      );
    } on FormatException {
      throw LandmarkServiceException('API returned malformed JSON');
    } on LandmarkServiceException {
      rethrow;
    } catch (e) {
      throw LandmarkServiceException('Unexpected error: $e');
    }
  }
}
