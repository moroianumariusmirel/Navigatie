import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trailpulse/core/models/activity_type.dart';
import 'package:trailpulse/core/routing/osm_routing_service.dart';

void main() {
  group('OsmRoutingService Offline Fallback Tests', () {
    setUp(() {
      OsmRoutingService.simulatedOfflineMode = true;
    });

    tearDown(() {
      OsmRoutingService.simulatedOfflineMode = false;
    });

    test('calculateRoute falls back to OnDeviceOfflineRouter and follows roads instead of straight lines', () async {
      // Points between Bucharest and Campina
      final points = [
        const LatLng(44.4268, 26.1025), // Bucharest
        const LatLng(45.1200, 25.7400), // Campina
      ];

      final route = await OsmRoutingService.calculateRoute(
        points: points,
        activityType: ActivityType.cycling,
        customName: 'Bucharest to Campina Offline Test',
      );

      // Verify that offline route followed road network
      expect(route.coordinates.length, greaterThan(2),
          reason: 'Must not be a straight 2-point line! Must contain intermediate road nodes.');
      expect(route.totalDistanceKm, greaterThan(60.0));
      expect(route.maneuvers.isNotEmpty, isTrue);

      // Check that it followed DN1 via Ploiesti
      final hasPloiestiProximity = route.coordinates.any((c) =>
          (c.latitude - 44.9367).abs() < 0.05 && (c.longitude - 26.0129).abs() < 0.05);
      expect(hasPloiestiProximity, isTrue,
          reason: 'Offline route must pass through Ploiesti along DN1 rather than cutting straight across countryside');
    });
  });
}
