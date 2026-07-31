import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
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

  Future<String?> uploadImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileName = 'landmark_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await _supabase.storage.from('landmarks').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      
      final publicUrl = _supabase.storage.from('landmarks').getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      print("Supabase Storage Upload Error: $e");
      // Fallback: return image file path if storage upload is not configured
      return imageFile.path;
    }
  }

  Future<bool> addLandmark(Map<String, dynamic> data) async {
    try {
      final payload = <String, dynamic>{
        'name': data['name'],
        'category': data['category'] ?? 'Uncategorised',
        'description': data['description'] ?? '',
        'latitude': data['latitude'],
        'longitude': data['longitude'],
        'foundation_year': data['year']?.toString(),
      };
      if (data['image_url'] != null && data['image_url'].toString().isNotEmpty) {
        payload['image_url'] = data['image_url'];
      }
      try {
        await _supabase.from('landmarks').insert(payload);
      } on PostgrestException catch (pe) {
        if (pe.message.contains('image_url') || pe.code == 'PGRST204') {
          payload.remove('image_url');
          await _supabase.from('landmarks').insert(payload);
        } else {
          rethrow;
        }
      }
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
      final payload = <String, dynamic>{};
      if (data.containsKey('name') && data['name'] != null) payload['name'] = data['name'];
      if (data.containsKey('category') && data['category'] != null) payload['category'] = data['category'];
      if (data.containsKey('description') && data['description'] != null) payload['description'] = data['description'];
      if (data.containsKey('latitude') && data['latitude'] != null) payload['latitude'] = data['latitude'];
      if (data.containsKey('longitude') && data['longitude'] != null) payload['longitude'] = data['longitude'];
      if (data.containsKey('year') && data['year'] != null) payload['foundation_year'] = data['year'].toString();
      if (data.containsKey('foundation_year') && data['foundation_year'] != null) payload['foundation_year'] = data['foundation_year'].toString();
      if (data.containsKey('image_url') && data['image_url'] != null) payload['image_url'] = data['image_url'];

      if (payload.isEmpty) return true;

      try {
        await _supabase.from('landmarks').update(payload).eq('id', id);
      } on PostgrestException catch (pe) {
        if (pe.message.contains('image_url') || pe.code == 'PGRST204') {
          payload.remove('image_url');
          if (payload.isNotEmpty) {
            await _supabase.from('landmarks').update(payload).eq('id', id);
          }
        } else {
          rethrow;
        }
      }

      notifyDataChanged();
      return true;
    } catch (e) {
      print("Supabase Update Error: $e");
      return false;
    }
  }

}
