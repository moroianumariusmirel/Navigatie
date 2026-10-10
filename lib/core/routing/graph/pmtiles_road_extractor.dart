import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:latlong2/latlong.dart';
import 'package:pmtiles/pmtiles.dart';
// ignore: implementation_imports
import 'package:pmtiles/src/directory.dart' as pmtiles_dir;
import 'package:vector_tile/vector_tile.dart';
import '../offline_routing_graph.dart';

/// A raw road segment extracted from a vector tile feature
class ExtractedRoadSegment {
  final List<LatLng> points;
  final RoadType roadType;
  final String? name;
  final bool isOneWay;

  const ExtractedRoadSegment({
    required this.points,
    required this.roadType,
    this.name,
    this.isOneWay = false,
  });
}

/// Extractor that scans `.pmtiles` archives at zoom 14 and extracts routable road geometry
class PmtilesRoadExtractor {
  /// Maps Protomaps `kind` and `kind_detail` property tags to our [RoadType] enum
  static RoadType parseRoadType(Map<String, dynamic>? properties) {
    if (properties == null) return RoadType.residential;

    final kind = properties['kind']?.toString().toLowerCase();
    final detail = properties['kind_detail']?.toString().toLowerCase();

    // Specific detail check first
    if (detail != null) {
      switch (detail) {
        case 'motorway':
        case 'motorway_link':
          return RoadType.motorway;
        case 'trunk':
        case 'primary':
        case 'trunk_link':
        case 'primary_link':
          return RoadType.primary;
        case 'secondary':
        case 'secondary_link':
          return RoadType.secondary;
        case 'tertiary':
        case 'tertiary_link':
          return RoadType.tertiary;
        case 'residential':
        case 'living_street':
        case 'unclassified':
        case 'service':
          return RoadType.residential;
        case 'track':
          return RoadType.track;
        case 'path':
        case 'bridleway':
          return RoadType.path;
        case 'cycleway':
          return RoadType.cycleway;
        case 'footway':
        case 'pedestrian':
        case 'steps':
          return RoadType.footway;
      }
    }

    if (kind != null) {
      switch (kind) {
        case 'highway':
        case 'major_road':
          return RoadType.primary;
        case 'minor_road':
          return RoadType.secondary;
        case 'track':
          return RoadType.track;
        case 'path':
          return RoadType.path;
        case 'cycleway':
          return RoadType.cycleway;
        case 'footway':
        case 'pedestrian':
          return RoadType.footway;
        case 'other':
          return RoadType.residential;
      }
    }

    return RoadType.residential;
  }

  /// Converts tile local coordinates (0..extent) at (z, x, y) to global [LatLng]
  static LatLng tilePixelToLatLng(double px, double py, int extent, int z, int x, int y) {
    final double totalTiles = math.pow(2, z).toDouble();
    final double worldX = (x + px / extent) / totalTiles;
    final double worldY = (y + py / extent) / totalTiles;

    final double lon = worldX * 360.0 - 180.0;
    final double n = math.pi - 2.0 * math.pi * worldY;
    final double lat = 180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));

    return LatLng(lat, lon);
  }

  /// Scans a PMTiles file and yields all road segments across all zoom 14 tiles
  static Future<List<ExtractedRoadSegment>> extractRoadSegments(
    File pmtilesFile, {
    void Function(double progress, String status)? onProgress,
  }) async {
    final archive = await PmTilesArchive.fromFile(pmtilesFile);
    final segments = <ExtractedRoadSegment>[];

    try {
      final header = archive.header;
      final leafOffset = header.leafDirectoriesOffset;

      // Collect all tile IDs at zoom 14 by traversing root and any leaf directories
      final targetTileIds = <int>{};
      final dirQueue = <pmtiles_dir.Directory>[archive.root];

      final raf = await pmtilesFile.open(mode: FileMode.read);
      try {
        while (dirQueue.isNotEmpty) {
          final dir = dirQueue.removeLast();
          for (final entry in dir.entries) {
            if (entry.isLeaf) {
              if (leafOffset > 0 && entry.length > 0) {
                await raf.setPosition(leafOffset + entry.offset);
                final compressed = await raf.read(entry.length);
                final uncompressed = header.internalCompression == Compression.none
                    ? compressed
                    : zlib.decoder.convert(compressed);
                final leafDir = pmtiles_dir.Directory.from(uncompressed, header: header);
                dirQueue.add(leafDir);
              }
            } else {
              final runLength = entry.runLength > 0 ? entry.runLength : 1;
              for (int i = 0; i < runLength; i++) {
                final id = entry.tileId + i;
                final zxy = ZXY.fromTileId(id);
                if (zxy.z == 14) {
                  targetTileIds.add(id);
                }
              }
            }
          }
        }
      } finally {
        await raf.close();
      }

      final sortedTileIds = targetTileIds.toList()..sort();
      final total = sortedTileIds.length;
      int processed = 0;

      for (final tileId in sortedTileIds) {
        final zxy = ZXY.fromTileId(tileId);
        final tile = await archive.tile(tileId);
        final bytes = tile.bytes();
        if (bytes.isNotEmpty) {
          final vTile = VectorTile.fromBytes(bytes: Uint8List.fromList(bytes));

          for (final layer in vTile.layers) {
            if (layer.name == 'roads' || layer.name == 'transportation') {
              final extent = layer.extent;

              for (final feat in layer.features) {
                final props = feat.properties?.map((k, v) => MapEntry(k, v.value));
                final roadType = parseRoadType(props);

                final name = props?['name']?.toString();
                final onewayVal = props?['oneway'];
                final isOneWay = onewayVal == true || onewayVal == 'yes' || onewayVal == 1;

                feat.decodeGeometry();
                final geom = feat.geometry;

                if (geom is GeometryLineString) {
                  final pts = <LatLng>[];
                  for (final pair in geom.coordinates) {
                    if (pair.length >= 2) {
                      pts.add(tilePixelToLatLng(pair[0], pair[1], extent, zxy.z, zxy.x, zxy.y));
                    }
                  }
                  if (pts.length >= 2) {
                    segments.add(ExtractedRoadSegment(
                      points: pts,
                      roadType: roadType,
                      name: name,
                      isOneWay: isOneWay,
                    ));
                  }
                } else if (geom is GeometryMultiLineString) {
                  for (final line in geom.coordinates) {
                    final pts = <LatLng>[];
                    for (final pair in line) {
                      if (pair.length >= 2) {
                        pts.add(tilePixelToLatLng(pair[0], pair[1], extent, zxy.z, zxy.x, zxy.y));
                      }
                    }
                    if (pts.length >= 2) {
                      segments.add(ExtractedRoadSegment(
                        points: pts,
                        roadType: roadType,
                        name: name,
                        isOneWay: isOneWay,
                      ));
                    }
                  }
                }
              }
            }
          }
        }

        processed++;
        if (processed % 100 == 0 || processed == total) {
          final p = total > 0 ? processed / total : 1.0;
          onProgress?.call(p, 'Reading tile $processed of $total...');
        }
      }
    } finally {
      await archive.close();
    }

    return segments;
  }
}
