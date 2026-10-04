import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'offline_download_service.dart';

class DeviceStorageService {
  /// Formats byte size into human-readable string (KB, MB, GB)
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 MB';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// Calculates total size of all .pmtiles files stored in offline_maps directory
  static Future<int> getOfflineMapsTotalBytes() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final mapsDir = Directory('${appDocDir.path}/offline_maps');
      if (!mapsDir.existsSync()) return 0;

      int total = 0;
      final files = mapsDir.listSync().whereType<File>();
      for (final f in files) {
        if (f.path.endsWith('.pmtiles')) {
          total += f.lengthSync();
        }
      }
      return total;
    } catch (e) {
      debugPrint('[DeviceStorageService] Error calculating storage: $e');
      return 0;
    }
  }

  /// Returns storage summary for the UI
  static Future<Map<String, dynamic>> getStorageSummary() async {
    final bytesUsed = await getOfflineMapsTotalBytes();
    final usedMb = bytesUsed / (1024 * 1024);
    final downloadService = OfflineDownloadService();
    final downloadedCount = downloadService.downloadedRegions.length;

    return {
      'usedBytes': bytesUsed,
      'usedMb': double.parse(usedMb.toStringAsFixed(1)),
      'usedFormatted': formatBytes(bytesUsed),
      'downloadedCount': downloadedCount,
    };
  }
}
