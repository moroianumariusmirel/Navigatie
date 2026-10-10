import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DownloadForegroundBridge {
  static const MethodChannel _channel = MethodChannel('com.trailpulse/download_service');

  /// Starts the native foreground service on Android with an ongoing notification.
  /// Safely no-ops on other platforms or during unit tests.
  static Future<void> start({
    required String title,
    required int progressPercent,
    required String text,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startDownloadForeground', {
        'title': title,
        'progress': progressPercent,
        'text': text,
      });
    } catch (e) {
      debugPrint('[DownloadForegroundBridge] start error: $e');
    }
  }

  /// Updates the progress bar and description text on the notification.
  static Future<void> update({
    required String title,
    required int progressPercent,
    required String text,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateDownloadProgress', {
        'title': title,
        'progress': progressPercent,
        'text': text,
      });
    } catch (e) {
      debugPrint('[DownloadForegroundBridge] update error: $e');
    }
  }

  /// Stops and tears down the native foreground service.
  static Future<void> stop() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopDownloadForeground');
    } catch (e) {
      debugPrint('[DownloadForegroundBridge] stop error: $e');
    }
  }
}
