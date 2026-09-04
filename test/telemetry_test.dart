import 'package:flutter_test/flutter_test.dart';
import 'package:trailpulse/core/models/telemetry_data.dart';
import 'package:trailpulse/core/routing/map_matcher.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('Telemetry & Spatial Tracking Tests', () {
    test('TelemetryData initial state is valid and progress calculation works', () {
      const data = TelemetryData(
        distanceTraveledKm: 20.0,
        totalDistanceKm: 40.0,
      );

      expect(data.progressPercentage, equals(0.5));
      expect(data.isHeartRatePeakAlert, isTrue);
      expect(data.heartRateBpm, equals(176));
    });

    test('MapMatcher detects off-route corridor deviation correctly', () {
      final matcher = MapMatcher();
      final route = [
        const LatLng(47.912, 7.892),
        const LatLng(47.915, 7.895),
        const LatLng(47.918, 7.898),
      ];

      // On-route point (very close to second point)
      final onTrackResult = matcher.matchToRoute(
        gpsPosition: const LatLng(47.91505, 7.89505),
        routePoints: route,
      );
      expect(onTrackResult.isOffRoute, isFalse);
      expect(onTrackResult.crossTrackDistanceMeters, lessThan(15.0));

      // Off-route point (diverged by ~100m)
      final offTrackResult = matcher.matchToRoute(
        gpsPosition: const LatLng(47.925, 7.910),
        routePoints: route,
      );
      expect(offTrackResult.isOffRoute, isTrue);
      expect(offTrackResult.crossTrackDistanceMeters, greaterThan(MapMatcher.offRouteThresholdMeters));
    });
  });
}
