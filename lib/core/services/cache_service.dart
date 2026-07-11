import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Get cached data
  Future<T?> get<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      if (_prefs == null) await initialize();
      final jsonString = _prefs!.getString(key);
      if (jsonString == null) return null;

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return fromJson(json);
    } catch (e) {
      debugPrint('Cache get error for key $key: $e');
      return null;
    }
  }

  // Get cached list
  Future<List<T>?> getList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      if (_prefs == null) await initialize();
      final jsonString = _prefs!.getString(key);
      if (jsonString == null) return null;

      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((item) => fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Cache getList error for key $key: $e');
      return null;
    }
  }

  // Set cached data
  Future<bool> set<T>(
    String key,
    T data,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      if (_prefs == null) await initialize();
      final json = toJson(data);
      final jsonString = jsonEncode(json);
      return await _prefs!.setString(key, jsonString);
    } catch (e) {
      debugPrint('Cache set error for key $key: $e');
      return false;
    }
  }

  // Set cached list
  Future<bool> setList<T>(
    String key,
    List<T> data,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    try {
      if (_prefs == null) await initialize();
      final jsonList = data.map((item) => toJson(item)).toList();
      final jsonString = jsonEncode(jsonList);
      return await _prefs!.setString(key, jsonString);
    } catch (e) {
      debugPrint('Cache setList error for key $key: $e');
      return false;
    }
  }

  // Get timestamp
  Future<DateTime?> getTimestamp(String key) async {
    try {
      if (_prefs == null) await initialize();
      final timestamp = _prefs!.getInt(key);
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      debugPrint('Cache getTimestamp error for key $key: $e');
      return null;
    }
  }

  // Set timestamp
  Future<bool> setTimestamp(String key) async {
    try {
      if (_prefs == null) await initialize();
      return await _prefs!.setInt(key, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Cache setTimestamp error for key $key: $e');
      return false;
    }
  }

  // Check if cache is valid
  Future<bool> isCacheValid(String timestampKey, Duration duration) async {
    try {
      final timestamp = await getTimestamp(timestampKey);
      if (timestamp == null) return false;

      final now = DateTime.now();
      final difference = now.difference(timestamp);
      return difference < duration;
    } catch (e) {
      debugPrint('Cache validation error: $e');
      return false;
    }
  }

  // Remove cache
  Future<bool> remove(String key) async {
    try {
      if (_prefs == null) await initialize();
      return await _prefs!.remove(key);
    } catch (e) {
      debugPrint('Cache remove error for key $key: $e');
      return false;
    }
  }

  // Clear all cache
  Future<bool> clear() async {
    try {
      if (_prefs == null) await initialize();
      return await _prefs!.clear();
    } catch (e) {
      debugPrint('Cache clear error: $e');
      return false;
    }
  }
}
