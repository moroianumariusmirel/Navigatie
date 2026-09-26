import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class AppPreferencesPlatformStorage {
  static const String _fileName = 'app_preferences.json';
  static Directory? testDirectory;

  static Future<File?> _getPreferencesFile() async {
    try {
      if (testDirectory != null) {
        return File('${testDirectory!.path}/$_fileName');
      }
      final docDir = await getApplicationDocumentsDirectory();
      return File('${docDir.path}/$_fileName');
    } catch (e) {
      debugPrint('[AppPreferencesPlatformStorage] Error getting documents directory: $e');
      return null;
    }
  }

  static Future<void> _writeQueue = Future.value();

  /// Awaits all pending preference read/write disk operations
  static Future<void> flush() => _writeQueue;

  static Future<Map<String, dynamic>> loadPreferences() {
    return _writeQueue.then((_) async {
      try {
        final file = await _getPreferencesFile();
        if (file == null || !await file.exists()) {
          return <String, dynamic>{};
        }
        final jsonStr = await file.readAsString();
        if (jsonStr.trim().isEmpty) return <String, dynamic>{};
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        return <String, dynamic>{};
      } catch (e) {
        debugPrint('[AppPreferencesPlatformStorage] Error loading preferences: $e');
        return <String, dynamic>{};
      }
    });
  }

  static Future<bool> savePreferences(Map<String, dynamic> prefs) {
    final task = _writeQueue.then((_) async {
      try {
        final file = await _getPreferencesFile();
        if (file == null) return false;
        final jsonStr = jsonEncode(prefs);
        final tempFile = File('${file.path}.tmp');
        await tempFile.writeAsString(jsonStr, flush: true);
        if (Platform.isWindows && await file.exists()) {
          await file.delete();
        }
        await tempFile.rename(file.path);
        debugPrint('[AppPreferencesPlatformStorage] Saved preferences atomically: $jsonStr');
        return true;
      } catch (e) {
        debugPrint('[AppPreferencesPlatformStorage] Error saving preferences: $e');
        return false;
      }
    });

    _writeQueue = task.then((_) {});
    return task;
  }
}
