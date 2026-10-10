import 'dart:io';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import '../offline_routing_graph.dart';
import 'pmtiles_road_extractor.dart';

/// Builds an [OfflineRoutingGraph] from raw extracted road segments,
/// snapping nearby endpoints to heal tile boundaries and connecting intersections.
class RoadGraphBuilder {
  static const Distance _distCalc = Distance();

  /// Coordinate quantization tolerance (~3.3 meters at 45 deg latitude)
  /// 0.00003 deg latitude ≈ 3.3 meters.
  static const double snapGridSize = 0.00003;

  static String _snapKey(double lat, double lon) {
    final y = (lat / snapGridSize).round();
    final x = (lon / snapGridSize).round();
    return '$y:$x';
  }

  /// Takes extracted road segments and builds a connected topological graph
  static OfflineRoutingGraph buildGraph(List<ExtractedRoadSegment> segments) {
    final graph = OfflineRoutingGraph();

    // Map each snapped coordinate bucket to a single unique node ID
    final nodeKeyToId = <String, int>{};
    int nextNodeId = 1;

    int getOrCreateNode(LatLng point) {
      final key = _snapKey(point.latitude, point.longitude);
      final existingId = nodeKeyToId[key];
      if (existingId != null) {
        return existingId;
      }

      final id = nextNodeId++;
      nodeKeyToId[key] = id;
      graph.addNode(RoutingNode(
        id: id,
        lat: point.latitude,
        lon: point.longitude,
      ));
      return id;
    }

    for (final seg in segments) {
      if (seg.points.length < 2) continue;

      for (int i = 0; i < seg.points.length - 1; i++) {
        final p1 = seg.points[i];
        final p2 = seg.points[i + 1];

        final id1 = getOrCreateNode(p1);
        final id2 = getOrCreateNode(p2);

        if (id1 == id2) continue; // Same snapped node

        final dist = _distCalc.as(LengthUnit.Meter, p1, p2);
        if (dist < 0.1) continue;

        graph.addEdge(RoutingEdge(
          sourceId: id1,
          targetId: id2,
          distanceMeters: dist,
          roadType: seg.roadType,
          name: seg.name,
          isOneWay: seg.isOneWay,
          geometry: [p1, p2],
        ));
      }
    }

    return graph;
  }

  /// Builds a graph directly from a PMTiles file and saves it as `.rgraph` binary/json
  static Future<OfflineRoutingGraph> buildAndSaveFromPmtiles(
    File pmtilesFile,
    File destinationRgraphFile, {
    void Function(double progress, String status)? onProgress,
  }) async {
    onProgress?.call(0.1, 'Extracting roads from vector tiles...');
    final segments = await PmtilesRoadExtractor.extractRoadSegments(
      pmtilesFile,
      onProgress: (p, s) {
        onProgress?.call(0.1 + p * 0.7, s);
      },
    );

    onProgress?.call(0.85, 'Connecting road network topology...');
    final graph = buildGraph(segments);

    onProgress?.call(0.95, 'Saving offline routing graph...');
    final jsonStr = graph.toJsonString();
    await destinationRgraphFile.writeAsString(jsonStr);

    onProgress?.call(1.0, 'Offline routing graph ready!');
    return graph;
  }
}
