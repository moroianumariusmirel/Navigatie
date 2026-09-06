import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/activity_type.dart';

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

  /// Primary tile layer selected dynamically based on ActivityType
  static TileLayer layerForActivity(ActivityType activity, {TileProvider? tileProvider}) {
    final tp = tileProvider ?? overrideTileProvider;
    if (activity == ActivityType.cycling) {
      return cyclOsmLayer(tileProvider: tp);
    } else {
      return openTopoMapLayer(tileProvider: tp);
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
