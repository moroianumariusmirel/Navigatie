import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';
import '../storage/app_preferences_service.dart';
import 'offline_tile_manager.dart';

class OfflineDownloadService extends ChangeNotifier {
  static final OfflineDownloadService _instance = OfflineDownloadService._internal();
  factory OfflineDownloadService() => _instance;
  OfflineDownloadService._internal();

  @visibleForTesting
  OfflineDownloadService.test();

  List<OfflineCountry> _countries = OfflineTileManager.europeanCountries();
  List<OfflineCountry> get countries => List.unmodifiable(_countries);

  final Map<String, bool> _cancelTokens = {};
  final Map<String, http.Client> _activeClients = {};
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  double _totalStorageUsedMb = 0.0;
  double get totalStorageUsedMb => _totalStorageUsedMb;

  /// Loads downloaded regions registry and syncs with on-device files
  Future<void> initialize() async {
    try {
      final baseDir = await _getOfflineMapsDirectory();
      if (!baseDir.existsSync()) {
        baseDir.createSync(recursive: true);
      }

      final prefs = await AppPreferencesService.loadPreferences();
      final downloadedRegistry = prefs['downloadedOfflineRegions'];

      final Map<String, String> registeredPaths = {};
      if (downloadedRegistry is List) {
        for (final item in downloadedRegistry) {
          if (item is Map && item['id'] is String && item['path'] is String) {
            final path = item['path'] as String;
            if (File(path).existsSync()) {
              registeredPaths[item['id'] as String] = path;
            }
          }
        }
      }

      // Check on-disk pmtiles files that match region IDs
      final onDiskFiles = baseDir.listSync().whereType<File>();
      for (final file in onDiskFiles) {
        final filename = file.uri.pathSegments.last;
        if (filename.endsWith('.pmtiles') && !filename.endsWith('.part')) {
          final regionId = filename.substring(0, filename.length - 8);
          registeredPaths[regionId] = file.path;
        }
      }

      // Sync state with catalog
      _countries = _countries.map((country) {
        final updatedRegions = country.regions.map((region) {
          final localPath = registeredPaths[region.id];
          if (localPath != null && File(localPath).existsSync()) {
            final fileSize = File(localPath).lengthSync();
            return region.copyWith(
              state: RegionDownloadState.ready,
              downloadProgress: 1.0,
              localPmtilesPath: localPath,
              downloadedBytes: fileSize,
              totalBytes: fileSize,
            );
          }
          return region;
        }).toList();

        return OfflineCountry(
          id: country.id,
          name: country.name,
          flag: country.flag,
          totalSizeMb: country.totalSizeMb,
          regions: updatedRegions,
        );
      }).toList();

      _calculateTotalStorage();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[OfflineDownloadService] Init error: $e');
    }
  }

  Future<Directory> _getOfflineMapsDirectory() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      return Directory('${appDocDir.path}/offline_maps');
    } catch (e) {
      // Fallback for tests
      return Directory(Directory.systemTemp.path);
    }
  }

  void _calculateTotalStorage() {
    double total = 0.0;
    for (final country in _countries) {
      for (final region in country.regions) {
        if (region.state == RegionDownloadState.ready && region.localPmtilesPath != null) {
          final file = File(region.localPmtilesPath!);
          if (file.existsSync()) {
            total += file.lengthSync() / (1024 * 1024);
          } else {
            total += region.sizeMb;
          }
        }
      }
    }
    _totalStorageUsedMb = double.parse(total.toStringAsFixed(1));
  }

  List<OfflineMapRegion> get downloadedRegions {
    final list = <OfflineMapRegion>[];
    for (final c in _countries) {
      for (final r in c.regions) {
        if (r.state == RegionDownloadState.ready) {
          list.add(r);
        }
      }
    }
    return list;
  }

  OfflineMapRegion? findRegionForCoordinates(LatLng point) {
    // 1. Prefer specific sub-regions first
    for (final c in _countries) {
      for (final r in c.subRegions) {
        if (r.state == RegionDownloadState.ready && r.contains(point)) {
          return r;
        }
      }
    }
    // 2. Check national master regions
    for (final c in _countries) {
      final master = c.masterRegion;
      if (master != null &&
          master.state == RegionDownloadState.ready &&
          master.contains(point)) {
        return master;
      }
    }
    return null;
  }

  bool isLocationCoveredOffline(LatLng point) =>
      findRegionForCoordinates(point) != null;

  /// Starts downloading a region (streams to disk with progress callbacks)
  Future<void> startDownload(OfflineMapRegion targetRegion, {bool simulate = false}) async {
    final regionId = targetRegion.id;
    _cancelTokens[regionId] = false;

    _updateRegionState(regionId, (r) => r.copyWith(
          state: RegionDownloadState.downloading,
          downloadProgress: 0.02,
        ));

    try {
      final mapsDir = await _getOfflineMapsDirectory();
      if (!mapsDir.existsSync()) {
        mapsDir.createSync(recursive: true);
      }
      final targetFile = File('${mapsDir.path}/$regionId.pmtiles');
      final tempFile = File('${mapsDir.path}/$regionId.pmtiles.part');

      // Check if simulation or real HTTP download
      final isDemoUrl = targetRegion.downloadUrl.contains('example.com') ||
          targetRegion.downloadUrl.contains('github.com/trailpulse') ||
          simulate;

      if (isDemoUrl) {
        await _simulateDownload(targetRegion, tempFile, targetFile);
      } else {
        await _realDownload(targetRegion, tempFile, targetFile);
      }

      if (_cancelTokens[regionId] == true) {
        if (tempFile.existsSync()) tempFile.deleteSync();
        _updateRegionState(regionId, (r) => r.copyWith(
              state: RegionDownloadState.notDownloaded,
              downloadProgress: 0.0,
            ));
        return;
      }

      // Mark ready and persist
      _updateRegionState(regionId, (r) => r.copyWith(
            state: RegionDownloadState.ready,
            downloadProgress: 1.0,
            localPmtilesPath: targetFile.path,
          ));

      await _persistDownloadedRegistry();
      _calculateTotalStorage();
      notifyListeners();
    } catch (e) {
      debugPrint('[OfflineDownloadService] Download error for $regionId: $e');
      _updateRegionState(regionId, (r) => r.copyWith(
            state: RegionDownloadState.notDownloaded,
            downloadProgress: 0.0,
          ));
    } finally {
      _cancelTokens.remove(regionId);
      _activeClients.remove(regionId);
    }
  }

  Future<void> _simulateDownload(
    OfflineMapRegion region,
    File tempFile,
    File targetFile,
  ) async {
    final regionId = region.id;
    const totalSteps = 20;
    final stepBytes = (region.sizeMb * 1024 * 1024 / totalSteps).round();

    final sink = tempFile.openWrite();
    for (int step = 1; step <= totalSteps; step++) {
      if (_cancelTokens[regionId] == true) {
        await sink.close();
        return;
      }
      await Future.delayed(const Duration(milliseconds: 100));
      sink.add(List.filled(1024, 0)); // write dummy data

      final progress = step / totalSteps;
      _updateRegionState(regionId, (r) => r.copyWith(
            downloadProgress: progress,
            downloadedBytes: step * stepBytes,
            totalBytes: (region.sizeMb * 1024 * 1024).round(),
          ));
    }
    await sink.close();

    if (targetFile.existsSync()) targetFile.deleteSync();
    await tempFile.rename(targetFile.path);
  }

  Future<void> _realDownload(
    OfflineMapRegion region,
    File tempFile,
    File targetFile,
  ) async {
    final regionId = region.id;
    final client = http.Client();
    _activeClients[regionId] = client;

    final request = http.Request('GET', Uri.parse(region.downloadUrl));
    final response = await client.send(request);

    if (response.statusCode >= 400) {
      throw Exception('HTTP error ${response.statusCode} downloading ${region.downloadUrl}');
    }

    final totalBytes = response.contentLength ?? (region.sizeMb * 1024 * 1024).round();
    int receivedBytes = 0;

    final sink = tempFile.openWrite();
    await for (final chunk in response.stream) {
      if (_cancelTokens[regionId] == true) {
        await sink.close();
        client.close();
        return;
      }
      sink.add(chunk);
      receivedBytes += chunk.length;
      final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);

      _updateRegionState(regionId, (r) => r.copyWith(
            downloadProgress: progress,
            downloadedBytes: receivedBytes,
            totalBytes: totalBytes,
          ));
    }
    await sink.close();
    client.close();

    if (targetFile.existsSync()) targetFile.deleteSync();
    await tempFile.rename(targetFile.path);
  }

  void cancelDownload(String regionId) {
    _cancelTokens[regionId] = true;
    _activeClients[regionId]?.close();
    _updateRegionState(regionId, (r) => r.copyWith(
          state: RegionDownloadState.notDownloaded,
          downloadProgress: 0.0,
        ));
    notifyListeners();
  }

  Future<void> deleteRegion(String regionId) async {
    for (final country in _countries) {
      for (final region in country.regions) {
        if (region.id == regionId) {
          if (region.localPmtilesPath != null) {
            final file = File(region.localPmtilesPath!);
            if (file.existsSync()) {
              try {
                file.deleteSync();
              } catch (e) {
                debugPrint('[OfflineDownloadService] Error deleting file: $e');
              }
            }
          }

          _updateRegionState(regionId, (r) => r.copyWith(
                state: RegionDownloadState.notDownloaded,
                downloadProgress: 0.0,
                localPmtilesPath: null,
                downloadedBytes: 0,
              ));

          await _persistDownloadedRegistry();
          _calculateTotalStorage();
          notifyListeners();
          return;
        }
      }
    }
  }

  /// Import user-supplied .pmtiles file directly from phone storage / USB
  Future<OfflineMapRegion?> importLocalPmtilesFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pmtiles'],
      );

      if (result == null || result.files.isEmpty) return null;
      final pickedPath = result.files.single.path;
      if (pickedPath == null) return null;

      final sourceFile = File(pickedPath);
      if (!sourceFile.existsSync()) return null;

      final mapsDir = await _getOfflineMapsDirectory();
      if (!mapsDir.existsSync()) mapsDir.createSync(recursive: true);

      final originalName = result.files.single.name;
      final targetFile = File('${mapsDir.path}/$originalName');
      await sourceFile.copy(targetFile.path);

      final fileSize = targetFile.lengthSync();
      final sizeMb = double.parse((fileSize / (1024 * 1024)).toStringAsFixed(1));

      // Check if file name matches any existing catalog region
      final baseId = originalName.replaceAll('.pmtiles', '').toLowerCase();
      OfflineMapRegion? matchedRegion;

      for (final c in _countries) {
        for (final r in c.regions) {
          if (r.id.toLowerCase() == baseId ||
              baseId.contains(r.id.toLowerCase()) ||
              r.name.toLowerCase().contains(baseId)) {
            matchedRegion = r;
            break;
          }
        }
        if (matchedRegion != null) break;
      }

      final importedRegion = (matchedRegion != null)
          ? matchedRegion.copyWith(
              state: RegionDownloadState.ready,
              downloadProgress: 1.0,
              localPmtilesPath: targetFile.path,
              downloadedBytes: fileSize,
              totalBytes: fileSize,
            )
          : OfflineMapRegion(
              id: 'imported_$baseId',
              countryId: 'custom',
              countryName: 'Imported',
              countryFlag: '📂',
              name: originalName,
              description: 'Imported local PMTiles vector archive',
              sizeMb: sizeMb,
              minLat: -90.0,
              minLon: -180.0,
              maxLat: 90.0,
              maxLon: 180.0,
              state: RegionDownloadState.ready,
              downloadProgress: 1.0,
              localPmtilesPath: targetFile.path,
              downloadedBytes: fileSize,
              totalBytes: fileSize,
            );

      _updateRegionState(importedRegion.id, (_) => importedRegion);
      await _persistDownloadedRegistry();
      _calculateTotalStorage();
      notifyListeners();
      return importedRegion;
    } catch (e) {
      debugPrint('[OfflineDownloadService] Import error: $e');
      return null;
    }
  }

  void _updateRegionState(String regionId, OfflineMapRegion Function(OfflineMapRegion) updater) {
    _countries = _countries.map((country) {
      final updated = country.regions.map((region) {
        if (region.id == regionId) {
          return updater(region);
        }
        return region;
      }).toList();

      return OfflineCountry(
        id: country.id,
        name: country.name,
        flag: country.flag,
        totalSizeMb: country.totalSizeMb,
        regions: updated,
      );
    }).toList();
    notifyListeners();
  }

  Future<void> _persistDownloadedRegistry() async {
    try {
      final registry = <Map<String, dynamic>>[];
      for (final country in _countries) {
        for (final region in country.regions) {
          if (region.state == RegionDownloadState.ready && region.localPmtilesPath != null) {
            registry.add(region.toJson());
          }
        }
      }
      final prefs = await AppPreferencesService.loadPreferences();
      prefs['downloadedOfflineRegions'] = registry;
      await AppPreferencesService.savePreferences(prefs);
    } catch (e) {
      debugPrint('[OfflineDownloadService] Persist error: $e');
    }
  }
}
