import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trailpulse/core/models/activity_type.dart';
import 'package:trailpulse/core/routing/osm_routing_service.dart';
import 'package:trailpulse/core/routing/graph/road_graph_builder.dart';

void main() {
  group('OsmRoutingService Offline Fallback Tests', () {
    final pmtilesFile = File('romania_bucegi_brasov.pmtiles');
    final rgraphFile = File('romania_bucegi_brasov.rgraph');

    setUpAll(() async {
      // Build test rgraph next to test pmtiles
      if (!rgraphFile.existsSync()) {
        await RoadGraphBuilder.buildAndSaveFromPmtiles(pmtilesFile, rgraphFile);
      }
    });

    tearDownAll(() {
      if (rgraphFile.existsSync()) {
        rgraphFile.deleteSync();
      }
    });

    setUp(() {
      OsmRoutingService.simulatedOfflineMode = true;
    });

    tearDown(() {
      OsmRoutingService.simulatedOfflineMode = false;
    });

    test('calculateRoute falls back to OnDeviceOfflineRouter and follows roads instead of straight lines', () async {
      // Points inside Bucegi/Brasov region (Brasov to Poiana Brasov)
      final points = [
        const LatLng(45.6420, 25.5900), // Brasov
        const LatLng(45.5950, 25.5530), // Poiana Brasov
      ];

      final route = await OsmRoutingService.calculateRoute(
        points: points,
        activityType: ActivityType.cycling,
        customName: 'Brasov to Poiana Offline Route',
      );

      // Verify that offline route followed road network
      expect(route.coordinates.length, greaterThan(10),
          reason: 'Must not be a straight 2-point line! Must contain intermediate road nodes.');
      expect(route.totalDistanceKm, greaterThan(4.0));
      expect(route.maneuvers.isNotEmpty, isTrue);
      expect(route.id.startsWith('offline_router'), isTrue,
          reason: 'Must be routed via on-device offline road router');
    });
  });
}
