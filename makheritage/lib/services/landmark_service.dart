import 'dart:convert';
import 'package:http/http.dart' as http;
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

    // Build REST API URL with optional filters
    String apiUrl = 'https://makheritage.onrender.com/api/landmarks';
    final queryParams = <String>[];
    if (category != null && category != 'All') queryParams.add('category=${Uri.encodeComponent(category)}');
    if (year != null) queryParams.add('year=$year');
    if (queryParams.isNotEmpty) apiUrl += '?${queryParams.join('&')}';

    // 1. Try Render REST API (bypasses Supabase RLS — reflects real updates)
    try {
      final res = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as List;
        final landmarks = decoded.map((json) => Landmark.fromJson(Map<String, dynamic>.from(json))).toList();
        // Save fresh data to cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(decoded));
        return landmarks;
      }
    } catch (_) {}

    // 2. Fallback: try Supabase directly
    try {
      var query = _supabase.from('landmarks').select();
      if (category != null && category != 'All') query = query.eq('category', category);
      if (year != null) query = query.eq('foundation_year', year.toString());
      final data = await query;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(data));
      return data.map((json) => Landmark.fromJson(json)).toList();
    } catch (_) {}

    // 3. Offline fallback: load from SharedPreferences cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final decoded = jsonDecode(cachedData) as List;
        return decoded.map((json) => Landmark.fromJson(Map<String, dynamic>.from(json))).toList();
      }
    } catch (_) {}

    throw LandmarkServiceException('Unable to load landmarks. Please check your connection.');
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
      return imageFile.path;
    }
  }

  Future<bool> addLandmark(Map<String, dynamic> data) async {
    bool success = false;
    final payload = <String, dynamic>{
      'name': data['name'],
      'category': data['category'] ?? 'Uncategorised',
      'description': data['description'] ?? '',
      'latitude': data['latitude'],
      'longitude': data['longitude'],
      'foundation_year': (data['year'] ?? data['foundation_year'])?.toString() ?? '',
    };
    if (data['image_url'] != null && data['image_url'].toString().isNotEmpty) {
      payload['image_url'] = data['image_url'];
    }

    try {
      final res = await http.post(
        Uri.parse('https://makheritage.onrender.com/api/landmarks'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        success = true;
      }
    } catch (e) {
      print("REST API Add Error: $e");
    }

    if (!success) {
      try {
        await _supabase.from('landmarks').insert(payload);
        success = true;
      } on PostgrestException catch (pe) {
        if (pe.message.contains('image_url') || pe.code == 'PGRST204') {
          payload.remove('image_url');
          try {
            await _supabase.from('landmarks').insert(payload);
            success = true;
          } catch (_) {}
        }
      } catch (e) {
        print("Supabase Direct Add Error: $e");
      }
    }

    notifyDataChanged();
    return true;
  }

  Future<bool> deleteLandmark(int id) async {
    try {
      await http.delete(Uri.parse('https://makheritage.onrender.com/api/landmarks/$id'));
    } catch (_) {}
    try {
      await _supabase.from('landmarks').delete().eq('id', id);
    } catch (_) {}
    notifyDataChanged();
    return true;
  }

  Future<bool> updateLandmark(int id, Map<String, dynamic> data) async {
    bool success = false;
    final payload = <String, dynamic>{};
    if (data.containsKey('name') && data['name'] != null) payload['name'] = data['name'];
    if (data.containsKey('category') && data['category'] != null) payload['category'] = data['category'];
    if (data.containsKey('description') && data['description'] != null) payload['description'] = data['description'];
    if (data.containsKey('latitude') && data['latitude'] != null) payload['latitude'] = data['latitude'];
    if (data.containsKey('longitude') && data['longitude'] != null) payload['longitude'] = data['longitude'];
    if (data.containsKey('year') && data['year'] != null) payload['foundation_year'] = data['year'].toString();
    if (data.containsKey('foundation_year') && data['foundation_year'] != null) payload['foundation_year'] = data['foundation_year'].toString();
    if (data.containsKey('image_url') && data['image_url'] != null) payload['image_url'] = data['image_url'];

    try {
      final res = await http.put(
        Uri.parse('https://makheritage.onrender.com/api/landmarks/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (res.statusCode == 200) {
        success = true;
      }
    } catch (e) {
      print("REST API Update Error: $e");
    }

    if (!success) {
      try {
        await _supabase.from('landmarks').update(payload).eq('id', id);
        success = true;
      } on PostgrestException catch (pe) {
        if (pe.message.contains('image_url') || pe.code == 'PGRST204') {
          payload.remove('image_url');
          if (payload.isNotEmpty) {
            try {
              await _supabase.from('landmarks').update(payload).eq('id', id);
              success = true;
            } catch (_) {}
          }
        }
      } catch (e) {
        print("Supabase Direct Update Error: $e");
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('cached_landmarks_')).toList();
      for (final key in keys) {
        final cachedStr = prefs.getString(key);
        if (cachedStr != null) {
          final decoded = jsonDecode(cachedStr) as List;
          final updatedList = decoded.map((item) {
            final map = Map<String, dynamic>.from(item);
            if (map['id'] == id) {
              if (payload.containsKey('name')) map['name'] = payload['name'];
              if (payload.containsKey('category')) map['category'] = payload['category'];
              if (payload.containsKey('description')) map['description'] = payload['description'];
              if (payload.containsKey('latitude')) map['latitude'] = payload['latitude'];
              if (payload.containsKey('longitude')) map['longitude'] = payload['longitude'];
              if (payload.containsKey('foundation_year')) map['foundation_year'] = payload['foundation_year'];
            }
            return map;
          }).toList();
          await prefs.setString(key, jsonEncode(updatedList));
        }
      }
    } catch (e) {
      print("Error updating local landmark cache: $e");
    }

    notifyDataChanged();
    return true;
  }
}
