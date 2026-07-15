import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/landmark.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Thrown for any network/parsing failure so the UI can show one
/// consistent "couldn't load" state instead of crashing.
class LandmarkServiceException implements Exception {
  final String message;
  LandmarkServiceException(this.message);

  @override
  String toString() => message;
}

class LandmarkService {
  static final String baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3000';

  final http.Client _client;

  LandmarkService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<Landmark>> fetchLandmarks({String? category}) async {
    final path = (category == null || category == 'All')
        ? '/api/landmarks'
        : '/api/landmarks?category=$category';
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
        'Could not reach the API. Is the backend running?',
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