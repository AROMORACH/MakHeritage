import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/landmark.dart';
import '../main.dart';

class LandmarkServiceException implements Exception {
  final String message;
  LandmarkServiceException(this.message);

  @override
  String toString() => message;
}

class LandmarkService {
  final _supabase = Supabase.instance.client;

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('cached_landmarks_')).toList();
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      print("Error clearing landmark cache: $e");
    }
  }

  void notifyDataChanged() {
    _clearCache();
    globalLandmarksRefreshNotifier.value++;
  }

  Future<List<Landmark>> fetchLandmarks({String? category, int? year}) async {
    final cacheKey = 'cached_landmarks_${category ?? "All"}_${year ?? "All"}';

    try {
      var query = _supabase.from('landmarks').select();
      
      if (category != null && category != 'All') {
        query = query.eq('category', category);
      }
      if (year != null) {
        query = query.eq('foundation_year', year.toString());
      }
      
      final data = await query;
      
      // Cache the raw JSON data for offline mode
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(data));
      
      return data.map((json) => Landmark.fromJson(json)).toList();
      
    } catch (e) {
      // Offline fallback: load from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);
      
      if (cachedData != null) {
         final decoded = jsonDecode(cachedData) as List;
         return decoded.map((json) => Landmark.fromJson(Map<String, dynamic>.from(json))).toList();
      }
      throw LandmarkServiceException('Offline and no cached data available. Error: $e');
    }
  }

  Future<bool> addLandmark(Map<String, dynamic> data) async {
    try {
      await _supabase.from('landmarks').insert({
        'name': data['name'],
        'category': data['category'] ?? 'Uncategorised',
        'description': data['description'] ?? '',
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'foundation_year': data['year']?.toString(), // Handle the backend conversion automatically
      });
      notifyDataChanged();
      return true;
    } catch (e) {
      print("Supabase Insert Error: $e");
      return false;
    }
  }

  Future<bool> deleteLandmark(int id) async {
    try {
      await _supabase.from('landmarks').delete().eq('id', id);
      notifyDataChanged();
      return true;
    } catch (e) {
      print("Supabase Delete Error: $e");
      return false;
    }
  }

  Future<bool> updateLandmark(int id, Map<String, dynamic> data) async {
    try {
      await _supabase.from('landmarks').update({
        'name': data['name'],
        'category': data['category'] ?? 'Uncategorised',
        'description': data['description'] ?? '',
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'foundation_year': data['year']?.toString(),
      }).eq('id', id);
      notifyDataChanged();
      return true;
    } catch (e) {
      print("Supabase Update Error: $e");
      return false;
    }
  }

}
