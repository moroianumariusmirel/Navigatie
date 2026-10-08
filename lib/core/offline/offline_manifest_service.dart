import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../storage/app_preferences_service.dart';
import 'offline_tile_manager.dart';

class RegionManifestInfo {
  final String regionId;
  final double sizeMb;
  final int totalBytes;
  final String? downloadUrl;
  final String? checksum;

  const RegionManifestInfo({
    required this.regionId,
    required this.sizeMb,
    required this.totalBytes,
    this.downloadUrl,
    this.checksum,
  });

  factory RegionManifestInfo.fromJson(String id, Map<String, dynamic> json) {
    final sizeMbVal = json['sizeMb'];
    final bytesVal = json['totalBytes'] ?? json['sizeBytes'];

    final double sizeMb = (sizeMbVal is num)
        ? sizeMbVal.toDouble()
        : (bytesVal is num ? (bytesVal.toDouble() / (1024 * 1024)) : 0.0);

    final int totalBytes = (bytesVal is num)
        ? bytesVal.toInt()
        : (sizeMbVal is num ? (sizeMbVal.toDouble() * 1024 * 1024).round() : 0);

    return RegionManifestInfo(
      regionId: id,
      sizeMb: double.parse(sizeMb.toStringAsFixed(1)),
      totalBytes: totalBytes,
      downloadUrl: json['downloadUrl'] as String?,
      checksum: json['checksum'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'regionId': regionId,
        'sizeMb': sizeMb,
        'totalBytes': totalBytes,
        if (downloadUrl != null) 'downloadUrl': downloadUrl,
        if (checksum != null) 'checksum': checksum,
      };
}

class OfflineManifest {
  final String version;
  final DateTime? updatedAt;
  final Map<String, RegionManifestInfo> regions;

  const OfflineManifest({
    required this.version,
    this.updatedAt,
    required this.regions,
  });

  factory OfflineManifest.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as String?) ?? '1.0.0';
    DateTime? updatedAt;
    if (json['updatedAt'] is String) {
      updatedAt = DateTime.tryParse(json['updatedAt'] as String);
    }

    final rawRegions = json['regions'];
    final Map<String, RegionManifestInfo> regions = {};

    if (rawRegions is Map) {
      rawRegions.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          regions[key.toString()] = RegionManifestInfo.fromJson(key.toString(), value);
        } else if (value is Map) {
          regions[key.toString()] = RegionManifestInfo.fromJson(
            key.toString(),
            Map<String, dynamic>.from(value),
          );
        }
      });
    }

    return OfflineManifest(
      version: version,
      updatedAt: updatedAt,
      regions: regions,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
        'regions': regions.map((k, v) => MapEntry(k, v.toJson())),
      };
}

class OfflineManifestService {
  static const String prefKey = 'cached_offline_manifest';
  static const Duration defaultTimeout = Duration(seconds: 5);

  /// Fetches the latest manifest from remote URL (e.g. GitHub Releases / CDN)
  static Future<OfflineManifest?> fetchRemoteManifest({
    String? url,
    http.Client? client,
  }) async {
    final targetUrl = url ?? OfflineTileManager.defaultManifestUrl;
    final httpClient = client ?? http.Client();

    try {
      final response = await httpClient
          .get(Uri.parse(targetUrl))
          .timeout(defaultTimeout);

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded is Map<String, dynamic>) {
          final manifest = OfflineManifest.fromJson(decoded);
          await saveCachedManifest(manifest);
          return manifest;
        }
      } else {
        debugPrint(
            '[OfflineManifestService] Remote manifest HTTP ${response.statusCode} from $targetUrl');
      }
    } catch (e) {
      debugPrint('[OfflineManifestService] Failed to fetch remote manifest ($e)');
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
    return null;
  }

  /// Loads locally cached manifest from persistent app preferences
  static Future<OfflineManifest?> loadCachedManifest() async {
    try {
      final prefs = await AppPreferencesService.loadPreferences();
      final cachedJson = prefs[prefKey];
      if (cachedJson is Map<String, dynamic>) {
        return OfflineManifest.fromJson(cachedJson);
      } else if (cachedJson is Map) {
        return OfflineManifest.fromJson(Map<String, dynamic>.from(cachedJson));
      } else if (cachedJson is String) {
        final decoded = json.decode(cachedJson);
        if (decoded is Map<String, dynamic>) {
          return OfflineManifest.fromJson(decoded);
        }
      }
    } catch (e) {
      debugPrint('[OfflineManifestService] Error reading cached manifest: $e');
    }
    return null;
  }

  /// Saves the manifest to persistent app preferences
  static Future<bool> saveCachedManifest(OfflineManifest manifest) async {
    try {
      final prefs = await AppPreferencesService.loadPreferences();
      prefs[prefKey] = manifest.toJson();
      return await AppPreferencesService.savePreferences(prefs);
    } catch (e) {
      debugPrint('[OfflineManifestService] Error saving cached manifest: $e');
      return false;
    }
  }

  /// Bundled fallback manifest with calibrated sizes for instant offline boot
  static OfflineManifest getBundledDefaultManifest() {
    return OfflineManifest(
      version: '1.0.0',
      updatedAt: DateTime(2026, 10, 8),
      regions: {
        'ro_all': const RegionManifestInfo(
          regionId: 'ro_all',
          sizeMb: 59.0,
          totalBytes: 61865984,
        ),
        'ro_bucegi_brasov': const RegionManifestInfo(
          regionId: 'ro_bucegi_brasov',
          sizeMb: 8.3,
          totalBytes: 8703180,
        ),
        'ro_transylvania_carpathians': const RegionManifestInfo(
          regionId: 'ro_transylvania_carpathians',
          sizeMb: 135.0,
          totalBytes: 141557760,
        ),
        'ro_muntenia_dobrogea': const RegionManifestInfo(
          regionId: 'ro_muntenia_dobrogea',
          sizeMb: 152.0,
          totalBytes: 159383552,
        ),
        'ro_moldavia_bucovina': const RegionManifestInfo(
          regionId: 'ro_moldavia_bucovina',
          sizeMb: 110.0,
          totalBytes: 115343360,
        ),
        'ro_banat_crisana': const RegionManifestInfo(
          regionId: 'ro_banat_crisana',
          sizeMb: 95.0,
          totalBytes: 99614720,
        ),
      },
    );
  }
}
