// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'package:flutter/foundation.dart';

class AppPreferencesPlatformStorage {
  static const String _storageKey = 'trailpulse_app_preferences';
  static Map<String, dynamic> _memoryFallback = {};

  static Future<void> flush() async {}

  static Future<Map<String, dynamic>> loadPreferences() async {
    try {
      final stored = html.window.localStorage[_storageKey];
      if (stored != null && stored.trim().isNotEmpty) {
        final decoded = jsonDecode(stored);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('[AppPreferencesPlatformStorage Web] Fallback to memory: $e');
    }
    return Map<String, dynamic>.from(_memoryFallback);
  }

  static Future<bool> savePreferences(Map<String, dynamic> prefs) async {
    try {
      html.window.localStorage[_storageKey] = jsonEncode(prefs);
      _memoryFallback = Map<String, dynamic>.from(prefs);
      return true;
    } catch (e) {
      debugPrint('[AppPreferencesPlatformStorage Web] Fallback saving memory: $e');
      _memoryFallback = Map<String, dynamic>.from(prefs);
      return true;
    }
  }
}
