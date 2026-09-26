import 'app_preferences_io.dart' if (dart.library.html) 'app_preferences_web.dart';

class AppPreferencesService {
  /// Loads saved user preferences from device storage or web localStorage
  static Future<Map<String, dynamic>> loadPreferences() {
    return AppPreferencesPlatformStorage.loadPreferences();
  }

  /// Persists user preferences to device storage or web localStorage
  static Future<bool> savePreferences(Map<String, dynamic> prefs) {
    return AppPreferencesPlatformStorage.savePreferences(prefs);
  }

  /// Flushes all pending preference operations
  static Future<void> flush() {
    return AppPreferencesPlatformStorage.flush();
  }
}
