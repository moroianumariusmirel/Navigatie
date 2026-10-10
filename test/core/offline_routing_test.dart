import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trailpulse/core/routing/offline_routing_graph.dart';
import 'package:trailpulse/core/routing/routing_engine.dart';
import 'package:trailpulse/core/routing/graph/pmtiles_road_extractor.dart';
import 'package:trailpulse/core/routing/graph/road_graph_builder.dart';

void main() {
  group('Real PMTiles Road Graph & A* Router Tests', () {
    late OfflineRoutingGraph graph;
    final pmtilesFile = File('romania_bucegi_brasov.pmtiles');
    final rgraphFile = File('test_brasov.rgraph');

    setUpAll(() async {
      expect(pmtilesFile.existsSync(), isTrue,
          reason: 'romania_bucegi_brasov.pmtiles must exist in repo for realistic tests');
      graph = await RoadGraphBuilder.buildAndSaveFromPmtiles(pmtilesFile, rgraphFile);
    });

    tearDownAll(() {
      OnDeviceOfflineRouter.invalidateCache();
      if (rgraphFile.existsSync()) {
        rgraphFile.deleteSync();
      }
    });

    test('Extracts thousands of real road nodes and edges from PMTiles z14 tiles', () {
      expect(graph.nodes.length, greaterThan(1000),
          reason: 'A real regional graph contains thousands of intersection nodes');
      expect(graph.adjacency.length, greaterThan(1000),
          reason: 'Graph must contain thousands of connected edges');
    });

    test('Snaps GPS tap to nearest real road within 100 meters', () {
      // Brasov old town center coordinate
      const brasovCenter = LatLng(45.6420, 25.5900);
      final nearest = graph.findNearestNode(brasovCenter, maxDistanceMeters: 500);

      expect(nearest, isNotNull);
      final dist = const Distance().as(LengthUnit.Meter, brasovCenter, nearest!.toLatLng);
      expect(dist, lessThan(300.0), reason: 'Should snap to a nearby street in Brasov');
    });

    test('Computes real road-following route between Brasov and Poiana Brasov', () {
      const brasovStart = LatLng(45.6420, 25.5900);
      const poianaTarget = LatLng(45.5950, 25.5530);

      final startNode = graph.findNearestNode(brasovStart);
      final endNode = graph.findNearestNode(poianaTarget);

      expect(startNode, isNotNull);
      expect(endNode, isNotNull);

      final path = graph.findPathAStar(
        startNodeId: startNode!.id,
        targetNodeId: endNode!.id,
        profile: OutdoorRoutingProfile.gravelBike,
      );

      expect(path, isNotNull);
      expect(path!.length, greaterThan(5),
          reason: 'A real road route comprises many connected street segments, not a straight cut');
    });

    test('OnDeviceOfflineRouter calculates RouteModel from local PMTiles road network', () async {
      final router = OnDeviceOfflineRouter();

      const brasovStart = LatLng(45.6420, 25.5900);
      const poianaTarget = LatLng(45.5950, 25.5530);

      final route = await router.calculateRoute(
        start: brasovStart,
        destination: poianaTarget,
        profile: OutdoorRoutingProfile.gravelBike,
        customName: 'Brasov to Poiana Test Route',
      );

      expect(route.coordinates.length, greaterThan(10),
          reason: 'Offline route must contain real road polyline points');
      expect(route.totalDistanceKm, greaterThan(4.0));
      expect(route.maneuvers.isNotEmpty, isTrue);
      expect(route.name, 'Brasov to Poiana Test Route');
    });
  });
}
