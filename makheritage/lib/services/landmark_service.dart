import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/landmark.dart';

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

  Future<List<Landmark>> fetchLandmarks({String? category, int? year}) async {
    final queryParams = <String, String>{};
    if (category != null && category != 'All') queryParams['category'] = category;
    if (year != null) queryParams['year'] = year.toString();

    final uri = Uri.parse('$baseUrl/api/landmarks').replace(queryParameters: queryParams);
    final cacheKey = 'cached_landmarks_${category ?? "All"}_${year ?? "All"}';

    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, response.body);
        return _parseJson(response.body);
      } else if (response.statusCode == 404) {
        throw LandmarkServiceException('No landmarks found (404)');
      } else {
        throw LandmarkServiceException('Server error (status ${response.statusCode})');
      }
    } on SocketException {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
        return _parseJson(cachedData);
      }
      throw LandmarkServiceException('Offline and no cached data available.');
    } on FormatException {
      throw LandmarkServiceException('API returned malformed JSON');
    } catch (e) {
      if (e is LandmarkServiceException) rethrow;
      throw LandmarkServiceException('Unexpected error: $e');
    }
  }

  List<Landmark> _parseJson(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! List) throw const FormatException();
    return decoded.whereType<Map<String, dynamic>>().map(Landmark.fromJson).toList();
  }
  Future<bool> addLandmark(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/api/landmarks');
    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode(data),
      );
      return response.statusCode == 201;
    } catch (e) {
      print("Error creating landmark: $e");
      return false;
    }
  }
}