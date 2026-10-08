import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trailpulse/core/routing/offline_routing_graph.dart';
import 'package:trailpulse/core/routing/regional_road_networks.dart';
import 'package:trailpulse/core/routing/routing_engine.dart';
import 'package:trailpulse/core/models/activity_type.dart';

void main() {
  group('OfflineRoutingGraph Tests', () {
    test('Snaps GPS coordinates to nearest road node', () {
      final graph = RegionalRoadNetworks.getMunteniaNetwork();

      // Near Bucharest Baneasa (44.4800, 26.0800 is node 102)
      final nearest = graph.findNearestNode(const LatLng(44.4810, 26.0790));
      expect(nearest, isNotNull);
      expect(nearest!.id, 102);
    });

    test('Computes valid A* path along road network between Bucharest and Sinaia', () {
      final graph = RegionalRoadNetworks.getMunteniaNetwork();

      // Start: Bucharest Center (101), Target: Sinaia (203)
      final path = graph.findPathAStar(
        startNodeId: 101,
        targetNodeId: 203,
        profile: OutdoorRoutingProfile.roadBike,
      );

      expect(path, isNotNull);
      expect(path!.isNotEmpty, isTrue);

      // Verify path flows along the road corridor
      // 101 -> 102 -> 201 (Ploiesti) -> 202 (Campina) -> 203 (Sinaia)
      final visitedNodes = <int>[101];
      for (final edge in path) {
        visitedNodes.add(edge.targetId);
      }

      expect(visitedNodes.contains(201), isTrue, reason: 'Must pass through Ploiesti (201)');
      expect(visitedNodes.contains(202), isTrue, reason: 'Must pass through Campina (202)');
      expect(visitedNodes.last, 203, reason: 'Must reach destination Sinaia (203)');
    });

    test('OnDeviceOfflineRouter generates full RouteModel with road coordinates', () async {
      final router = OnDeviceOfflineRouter();

      // Plan route from near Ploiesti to near Sinaia
      final route = await router.calculateRoute(
        start: const LatLng(44.9367, 26.0129), // Ploiesti
        destination: const LatLng(45.3500, 25.5500), // Sinaia
        profile: OutdoorRoutingProfile.roadBike,
        customName: 'Offline Test Road Route',
      );

      expect(route.coordinates.length, greaterThan(2),
          reason: 'Offline road router must produce multiple road coordinates, not just straight line');
      expect(route.totalDistanceKm, greaterThan(50.0));
      expect(route.maneuvers.isNotEmpty, isTrue);
      expect(route.name, 'Offline Test Road Route');
    });
  });
}
