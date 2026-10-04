import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';
import '../models/activity_type.dart';
import '../offline/offline_download_service.dart';
import '../offline/offline_tile_manager.dart';

enum MapLayerStyle {
  cyclosm,
  openTopoMap,
  standardOsm,
  waymarkedOverlay,
}

class OsmTileProviders {
  static const String cyclOsmUrl = 'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png';
  static const String openTopoMapUrl = 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
  static const String standardOsmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String waymarkedCyclingUrl = 'https://tile.waymarkedtrails.org/cycling/{z}/{x}/{y}.png';
  static const String waymarkedHikingUrl = 'https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png';

  /// Optional override for tests and offline mock fixtures
  static TileProvider? overrideTileProvider;

  /// Cache of active PMTiles providers to avoid recreating archive handles per frame
  static final Map<String, PmTilesVectorTileProvider> _pmtilesProviders = {};

  /// Primary tile layer selected dynamically based on ActivityType and center coordinates.
  /// If [center] is within a downloaded offline region with a valid local PMTiles archive,
  /// returns a high-performance [VectorTileLayer] styled for cycling/hiking.
  /// Otherwise, seamlessly falls back to online raster tiles.
  static Widget layerForActivity(
    ActivityType activity, {
    TileProvider? tileProvider,
    LatLng? center,
  }) {
    final tp = tileProvider ?? overrideTileProvider;
    if (center != null && tp == null) {
      final offlineLayer = getOfflineVectorLayerIfAvailable(center, activity);
      if (offlineLayer != null) {
        return offlineLayer;
      }
    }

    if (activity == ActivityType.cycling) {
      return cyclOsmLayer(tileProvider: tp);
    } else {
      return openTopoMapLayer(tileProvider: tp);
    }
  }

  /// Checks if [point] is inside a downloaded PMTiles file on the device
  static OfflineMapRegion? getActiveOfflineRegion(LatLng point) {
    try {
      final downloadService = OfflineDownloadService();
      return downloadService.findRegionForCoordinates(point);
    } catch (_) {
      return null;
    }
  }

  /// Builds a [VectorTileLayer] from a local PMTiles archive if available for [center]
  static Widget? getOfflineVectorLayerIfAvailable(LatLng center, ActivityType activity) {
    try {
      final region = getActiveOfflineRegion(center);
      if (region == null || region.localPmtilesPath == null) return null;

      final filePath = region.localPmtilesPath!;
      if (!File(filePath).existsSync()) return null;

      var provider = _pmtilesProviders[filePath];
      if (provider == null) {
        // Asynchronous caching or synchronous initialization
        // Note: For initial build, if not cached yet, we start initialization and fallback to online
        // until next frame
        PmTilesVectorTileProvider.fromSource(filePath).then((p) {
          _pmtilesProviders[filePath] = p;
        }).catchError((e) {
          debugPrint('[OsmTileProviders] Error loading PMTiles archive: $e');
        });
        return null;
      }

      // Select Protomaps Tactical Theme based on activity (Dark / Light)
      final theme = activity == ActivityType.cycling
          ? ProtomapsThemes.darkV4()
          : ProtomapsThemes.lightV4();

      return VectorTileLayer(
        key: ValueKey('pmtiles_${region.id}'),
        tileProviders: TileProviders({
          'protomaps': provider,
        }),
        theme: theme,
        layerMode: VectorTileLayerMode.vector,
      );
    } catch (e) {
      debugPrint('[OsmTileProviders] Offline vector layer error: $e');
      return null;
    }
  }

  /// CyclOSM - Designed specifically for bicycles, gravel tracks, MTB grades and smooth/rough surfaces
  static TileLayer cyclOsmLayer({TileProvider? tileProvider}) {
    final tp = tileProvider ?? overrideTileProvider;
    return TileLayer(
      urlTemplate: cyclOsmUrl,
      subdomains: const ['a', 'b', 'c'],
      userAgentPackageName: 'com.trailpulse.trailpulse',
      fallbackUrl: standardOsmUrl,
      tileProvider: tp,
      maxZoom: 20,
    );
  }

  /// OpenTopoMap - Topographic contour lines, hill contours, elevation summits and hiking paths
  static TileLayer openTopoMapLayer({TileProvider? tileProvider}) {
    final tp = tileProvider ?? overrideTileProvider;
    return TileLayer(
      urlTemplate: openTopoMapUrl,
      subdomains: const ['a', 'b', 'c'],
      userAgentPackageName: 'com.trailpulse.trailpulse',
      fallbackUrl: standardOsmUrl,
      tileProvider: tp,
      maxZoom: 17,
    );
  }

  /// Standard OpenStreetMap as clean reference fallback
  static TileLayer standardOsmLayer({TileProvider? tileProvider}) {
    final tp = tileProvider ?? overrideTileProvider;
    return TileLayer(
      urlTemplate: standardOsmUrl,
      userAgentPackageName: 'com.trailpulse.trailpulse',
      tileProvider: tp,
      maxZoom: 19,
    );
  }

  /// Waymarked Trails Cycling Overlay (transparent route overlay)
  static TileLayer waymarkedCyclingOverlay({TileProvider? tileProvider}) {
    final tp = tileProvider ?? overrideTileProvider;
    return TileLayer(
      urlTemplate: waymarkedCyclingUrl,
      userAgentPackageName: 'com.trailpulse.trailpulse',
      tileProvider: tp,
      maxZoom: 18,
    );
  }

  /// Waymarked Trails Hiking Overlay (transparent trail overlay)
  static TileLayer waymarkedHikingOverlay({TileProvider? tileProvider}) {
    final tp = tileProvider ?? overrideTileProvider;
    return TileLayer(
      urlTemplate: waymarkedHikingUrl,
      userAgentPackageName: 'com.trailpulse.trailpulse',
      tileProvider: tp,
      maxZoom: 18,
    );
  }
}

/// Lightweight memory-backed tile provider for automated testing and offline fallback
class MockWhiteTileProvider extends TileProvider {
  static final Uint8List _tileBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAQAAAAEAAQMAAABmvDolAAAAAXNSR0IB2cksfwAAAAlwSFlzAAALEwAACxMBAJqcGAAAAANQTFRF////p8QbyAAAAB9JREFUeJztwQENAAAAwqD3T20ON6AAAAAAAAAAAL4NIQAAAfFnIe4AAAAASUVORK5CYII=',
  );

  @override
  ImageProvider<Object> getImage(TileCoordinates coordinates, TileLayer options) {
    return MemoryImage(_tileBytes);
  }
}
