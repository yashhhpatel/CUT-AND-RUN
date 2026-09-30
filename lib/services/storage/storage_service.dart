import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin, fault-tolerant wrapper over SharedPreferences. Corrupted or
/// unexpected values never crash the game; they fall back to defaults.
class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static Future<StorageService> create() async => StorageService(await SharedPreferences.getInstance());

  int getInt(String key, [int fallback = 0]) {
    try {
      return _prefs.getInt(key) ?? fallback;
    } catch (e) {
      debugPrint('storage: bad int for $key: $e');
      return fallback;
    }
  }

  double getDouble(String key, [double fallback = 0]) {
    try {
      return _prefs.getDouble(key) ?? fallback;
    } catch (e) {
      debugPrint('storage: bad double for $key: $e');
      return fallback;
    }
  }

  bool getBool(String key, [bool fallback = false]) {
    try {
      return _prefs.getBool(key) ?? fallback;
    } catch (e) {
      debugPrint('storage: bad bool for $key: $e');
      return fallback;
    }
  }

  String getString(String key, [String fallback = '']) {
    try {
      return _prefs.getString(key) ?? fallback;
    } catch (e) {
      debugPrint('storage: bad string for $key: $e');
      return fallback;
    }
  }

  Map<String, dynamic> getJson(String key) {
    final raw = getString(key);
    if (raw.isEmpty) return {};
    try {
      final v = jsonDecode(raw);
      return v is Map<String, dynamic> ? v : {};
    } catch (e) {
      debugPrint('storage: corrupted json for $key, resetting: $e');
      return {};
    }
  }

  Set<String> getStringSet(String key) {
    try {
      return (_prefs.getStringList(key) ?? const []).toSet();
    } catch (e) {
      return {};
    }
  }

  Future<void> setInt(String key, int v) => _guard(() => _prefs.setInt(key, v));
  Future<void> setDouble(String key, double v) => _guard(() => _prefs.setDouble(key, v));
  Future<void> setBool(String key, bool v) => _guard(() => _prefs.setBool(key, v));
  Future<void> setString(String key, String v) => _guard(() => _prefs.setString(key, v));
  Future<void> setJson(String key, Map<String, dynamic> v) => setString(key, jsonEncode(v));
  Future<void> setStringSet(String key, Set<String> v) => _guard(() => _prefs.setStringList(key, v.toList()));

  Future<void> _guard(Future<bool> Function() op) async {
    try {
      await op();
    } catch (e) {
      debugPrint('storage: write failed: $e');
    }
  }
}
