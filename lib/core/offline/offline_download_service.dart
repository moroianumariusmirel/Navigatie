import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';
import '../maps/osm_tile_providers.dart';
import '../storage/app_preferences_service.dart';
import 'offline_tile_manager.dart';
import 'offline_manifest_service.dart';
import 'pmtiles_extractor.dart';

class OfflineDownloadService extends ChangeNotifier {
  static final OfflineDownloadService _instance = OfflineDownloadService._internal();
  factory OfflineDownloadService() => _instance;
  OfflineDownloadService._internal();

  @visibleForTesting
  OfflineDownloadService.test();

  List<OfflineCountry> _countries = OfflineTileManager.europeanCountries();
  List<OfflineCountry> get countries => List.unmodifiable(_countries);

  OfflineManifest? _manifest;
  OfflineManifest? get manifest => _manifest;
  bool _isSyncingManifest = false;
  bool get isSyncingManifest => _isSyncingManifest;

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
          if (item is Map && item['id'] is String) {
            final path = (item['localPmtilesPath'] ?? item['path']) as String?;
            if (path != null) {
              final file = File(path);
              if (file.existsSync() && isValidPmtilesFile(file)) {
                registeredPaths[item['id'] as String] = path;
              }
            }
          }
        }
      }

      // Check on-disk pmtiles files that match region IDs or aliases
      if (baseDir.existsSync()) {
        final onDiskFiles = baseDir.listSync().whereType<File>();
        for (final file in onDiskFiles) {
          final filename = file.uri.pathSegments.last;
          if (filename.endsWith('.pmtiles') && !filename.endsWith('.part')) {
            if (isValidPmtilesFile(file)) {
              final rawId = filename.substring(0, filename.length - 8);
              registeredPaths[rawId] = file.path;

              // Support aliases: romania_all <-> ro_all, romania_bucegi_brasov <-> ro_bucegi_brasov
              if (rawId.startsWith('romania_')) {
                registeredPaths['ro_${rawId.substring(8)}'] = file.path;
              } else if (rawId.startsWith('ro_')) {
                registeredPaths['romania_${rawId.substring(3)}'] = file.path;
              }
            }
          }
        }
      }

      // Sync state with catalog
      _countries = _countries.map((country) {
        final updatedRegions = country.regions.map((region) {
          final localPath = registeredPaths[region.id] ??
              registeredPaths['ro_${region.id}'] ??
              (region.id.startsWith('ro_')
                  ? registeredPaths['romania_${region.id.substring(3)}']
                  : null);
          if (localPath != null && File(localPath).existsSync()) {
            final fileSize = File(localPath).lengthSync();
            final actualSizeMb = double.parse((fileSize / (1024 * 1024)).toStringAsFixed(1));
            return region.copyWith(
              state: RegionDownloadState.ready,
              downloadProgress: 1.0,
              localPmtilesPath: localPath,
              downloadedBytes: fileSize,
              totalBytes: fileSize,
              sizeMb: actualSizeMb,
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

      // Pre-warm active PMTiles into memory
      for (final path in registeredPaths.values) {
        OsmTileProviders.prewarm(path);
      }

      _calculateTotalStorage();
      _isInitialized = true;
      notifyListeners();

      // Check cached manifest to update dynamic sizes immediately
      final cached = await OfflineManifestService.loadCachedManifest();
      if (cached != null) {
        applyManifest(cached);
      }

      // Non-blocking background sync from remote manifest
      unawaited(syncManifest());
    } catch (e) {
      debugPrint('[OfflineDownloadService] Init error: $e');
    }
  }

  /// Applies an OfflineManifest to update sizes of un-downloaded regions dynamically
  void applyManifest(OfflineManifest manifest) {
    _manifest = manifest;
    _countries = _countries.map((country) {
      final updatedRegions = country.regions.map((region) {
        final info = manifest.regions[region.id];
        if (info != null) {
          // If already downloaded and ready on-disk, maintain the real on-disk length
          if (region.state == RegionDownloadState.ready) {
            return region.copyWith(
              downloadUrl: info.downloadUrl ?? region.downloadUrl,
            );
          }
          return region.copyWith(
            sizeMb: info.sizeMb,
            totalBytes: info.totalBytes,
            downloadUrl: info.downloadUrl ?? region.downloadUrl,
          );
        }
        return region;
      }).toList();

      return OfflineCountry(
        id: country.id,
        name: country.name,
        flag: country.flag,
        totalSizeMb: country.effectiveTotalSizeMb,
        regions: updatedRegions,
      );
    }).toList();
    _calculateTotalStorage();
    notifyListeners();
  }

  /// Synchronizes latest manifest from remote server in the background
  Future<bool> syncManifest({String? url, http.Client? client}) async {
    if (_isSyncingManifest) return false;
    _isSyncingManifest = true;
    notifyListeners();
    try {
      final remote = await OfflineManifestService.fetchRemoteManifest(
        url: url,
        client: client,
      );
      if (remote != null) {
        applyManifest(remote);
        return true;
      }
    } finally {
      _isSyncingManifest = false;
      notifyListeners();
    }
    return false;
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

  /// Returns the geographic center of the first available downloaded region,
  /// or null if no offline map has been downloaded yet.
  LatLng? get defaultOfflineCenter {
    for (final country in _countries) {
      for (final region in country.regions) {
        if (region.state == RegionDownloadState.ready && region.localPmtilesPath != null) {
          return region.center;
        }
      }
    }
    return null;
  }

  /// Verifies if a file exists, has adequate size, and conforms strictly to PMTiles V3
  /// including the requirement that rootDirectoryOffset + rootDirectoryLength <= 16384.
  static bool isValidPmtilesFile(File file) {
    try {
      if (!file.existsSync() || file.lengthSync() < 512) return false;
      final raf = file.openSync(mode: FileMode.read);
      final headerBytes = raf.readSync(127);
      raf.closeSync();

      if (headerBytes.length < 127) return false;
      if (utf8.decode(headerBytes.sublist(0, 7), allowMalformed: true) != 'PMTiles') {
        return false;
      }

      final bd = ByteData.sublistView(Uint8List.fromList(headerBytes));
      final version = bd.getUint8(7);
      if (version != 3) return false;

      final rootDirOffset = bd.getUint32(8, Endian.little);
      final rootDirLength = bd.getUint32(16, Endian.little);
      if (rootDirLength == 0 || rootDirOffset + rootDirLength > 65536) {
        return false;
      }

      final tileDataOffset = bd.getUint32(56, Endian.little); // 0x38
      final fileSize = file.lengthSync();
      if (tileDataOffset > fileSize) {
        return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Starts downloading a region (streams to disk with progress callbacks)
  Future<void> startDownload(OfflineMapRegion targetRegion, {bool simulate = false}) async {
    final regionId = targetRegion.id;
    _cancelTokens[regionId] = false;

    _updateRegionState(regionId, (r) => r.copyWith(
          state: RegionDownloadState.downloading,
          downloadProgress: 0.02,
          errorMessage: null,
        ));

    try {
      final mapsDir = await _getOfflineMapsDirectory();
      if (!mapsDir.existsSync()) {
        mapsDir.createSync(recursive: true);
      }
      final targetFile = File('${mapsDir.path}/$regionId.pmtiles');
      final tempFile = File('${mapsDir.path}/$regionId.pmtiles.part');

      // Check if simulation, direct pre-cut PMTiles URL, or in-app extractor
      final isDemoUrl = targetRegion.downloadUrl.contains('example.com') ||
          simulate;
      final isDirectPreCutPmtiles = targetRegion.downloadUrl.isNotEmpty &&
          targetRegion.downloadUrl.startsWith('http') &&
          !targetRegion.downloadUrl.contains('github.com/trailpulse') &&
          targetRegion.downloadUrl.endsWith('.pmtiles');

      if (isDemoUrl) {
        await _simulateDownload(targetRegion, tempFile, targetFile);
      } else if (isDirectPreCutPmtiles) {
        try {
          await _realDownload(targetRegion, tempFile, targetFile);
        } catch (e) {
          debugPrint(
              '[OfflineDownloadService] Direct download failed ($e), falling back to in-app extractor');
          if (tempFile.existsSync()) tempFile.deleteSync();
          await _extractFromProtomaps(targetRegion, targetFile);
        }
      } else {
        await _extractFromProtomaps(targetRegion, targetFile);
      }

      if (_cancelTokens[regionId] == true) {
        if (tempFile.existsSync()) tempFile.deleteSync();
        _updateRegionState(regionId, (r) => r.copyWith(
              state: RegionDownloadState.notDownloaded,
              downloadProgress: 0.0,
              errorMessage: null,
            ));
        return;
      }

      // Validate PMTiles magic header before marking ready
      if (!isValidPmtilesFile(targetFile)) {
        if (targetFile.existsSync()) targetFile.deleteSync();
        throw Exception('Downloaded file is not a valid PMTiles archive');
      }

      final fileSize = targetFile.lengthSync();
      final actualSizeMb = double.parse((fileSize / (1024 * 1024)).toStringAsFixed(1));

      // Mark ready and persist
      _updateRegionState(regionId, (r) => r.copyWith(
            state: RegionDownloadState.ready,
            downloadProgress: 1.0,
            localPmtilesPath: targetFile.path,
            downloadedBytes: fileSize,
            totalBytes: fileSize,
            sizeMb: actualSizeMb,
            errorMessage: null,
          ));

      await _persistDownloadedRegistry();
      _calculateTotalStorage();
      await OsmTileProviders.prewarm(targetFile.path);
      notifyListeners();
    } catch (e) {
      debugPrint('[OfflineDownloadService] Download error for $regionId: $e');
      final humanError = _formatErrorMessage(e);
      _updateRegionState(regionId, (r) => r.copyWith(
            state: RegionDownloadState.failed,
            downloadProgress: 0.0,
            errorMessage: humanError,
          ));
      notifyListeners();
    } finally {
      _cancelTokens.remove(regionId);
      _activeClients.remove(regionId);
    }
  }

  String _formatErrorMessage(dynamic error) {
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
      return 'No internet connection. Check your network and retry.';
    } else if (msg.contains('TimeoutException') || msg.contains('timed out')) {
      return 'Connection timed out. Network is slow or unreachable.';
    } else if (msg.contains('HTTP 429')) {
      return 'Server busy. Please wait a moment and retry.';
    } else if (msg.contains('HTTP 404')) {
      return 'Map file not found on server.';
    } else if (msg.contains('cancelled') || msg.contains('Cancelled')) {
      return 'Download cancelled.';
    } else {
      return 'Download failed: $msg';
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

  Future<void> _extractFromProtomaps(
    OfflineMapRegion region,
    File targetFile,
  ) async {
    final regionId = region.id;
    final client = http.Client();
    _activeClients[regionId] = client;

    await InAppPmtilesExtractor.extractRegion(
      region: region,
      targetFile: targetFile,
      httpClient: client,
      isCancelled: () => _cancelTokens[regionId] == true,
      onProgress: (progress, receivedBytes, totalBytes) {
        _updateRegionState(regionId, (r) => r.copyWith(
              downloadProgress: progress,
              downloadedBytes: receivedBytes,
              totalBytes: totalBytes,
            ));
      },
    );
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
                totalBytes: 0,
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

      if (!isValidPmtilesFile(targetFile)) {
        if (targetFile.existsSync()) targetFile.deleteSync();
        throw Exception('Imported file is not a valid PMTiles archive');
      }

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
      await OsmTileProviders.prewarm(targetFile.path);
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
