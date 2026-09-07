import 'package:flutter_test/flutter_test.dart';
import 'package:trailpulse/core/models/telemetry_data.dart';
import 'package:trailpulse/core/models/route_model.dart';
import 'package:trailpulse/core/models/elevation_point.dart';
import 'package:trailpulse/core/models/activity_type.dart';
import 'package:trailpulse/core/telemetry/telemetry_service.dart';
import 'package:trailpulse/core/routing/map_matcher.dart';
import 'package:latlong2/latlong.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Telemetry & Spatial Tracking Tests', () {
    test('TelemetryData initial state is valid and progress calculation works', () {
      const data = TelemetryData(
        distanceTraveledKm: 20.0,
        totalDistanceKm: 40.0,
      );

      expect(data.progressPercentage, equals(0.5));
      expect(data.isHeartRatePeakAlert, isFalse);
      expect(data.heartRateBpm, isNull);
      expect(data.currentSpeedKmH, equals(0.0));

      const activeData = TelemetryData(
        distanceTraveledKm: 20.0,
        totalDistanceKm: 40.0,
        heartRateBpm: 176,
        isHeartRatePeakAlert: true,
      );
      expect(activeData.isHeartRatePeakAlert, isTrue);
      expect(activeData.heartRateBpm, equals(176));
    });

    test('TelemetryService initializes and synchronizes correctly from custom RouteModel', () {
      const customRoute = RouteModel(
        id: 'test_route_1',
        name: 'Custom Mountain Pass',
        activityType: ActivityType.cycling,
        totalDistanceKm: 10.0,
        totalAscentM: 500.0,
        totalDescentM: 100.0,
        maxElevationM: 1650.0,
        minElevationM: 1150.0,
        estimatedDuration: '45m',
        difficultyRating: 'S1',
        surfaceBreakdown: {'Gravel': 1.0},
        elevationProfile: [
          ElevationPoint(distanceKm: 0.0, elevationM: 1150.0, gradePercent: 3.5),
          ElevationPoint(distanceKm: 5.0, elevationM: 1400.0, gradePercent: 7.2),
          ElevationPoint(distanceKm: 10.0, elevationM: 1650.0, gradePercent: 9.0),
        ],
        maneuvers: [],
        coordinates: [
          LatLng(47.100, 7.100),
          LatLng(47.200, 7.200),
          LatLng(47.300, 7.300),
        ],
      );

      final service = TelemetryService(initialRoute: customRoute, autoStartSimulation: false);
      service.updateActiveRoute(customRoute);

      final data = service.currentData;
      expect(data.totalDistanceKm, equals(10.0));
      expect(data.distanceTraveledKm, equals(0.0));
      expect(data.distanceRemainingKm, equals(10.0));
      expect(data.currentElevationM, equals(1150.0));
      expect(data.currentGradePercent, equals(3.5));
      expect(data.apexElevationM, equals(1650.0));
      expect(data.maxGradePercent, equals(9.0));
      expect(data.ascentRemainingM, equals(500.0));
      expect(data.currentLatitude, equals(47.100));
      expect(data.currentLongitude, equals(7.100));
      expect(data.currentPosition, isNotNull);

      service.dispose();
    });

    test('TelemetryService calculates accurate linear interpolation of slope and elevation', () {
      const customRoute = RouteModel(
        id: 'test_route_2',
        name: 'Ridge Climb',
        activityType: ActivityType.cycling,
        totalDistanceKm: 10.0,
        totalAscentM: 600.0,
        totalDescentM: 0.0,
        maxElevationM: 1600.0,
        minElevationM: 1000.0,
        estimatedDuration: '40m',
        difficultyRating: 'S2',
        surfaceBreakdown: {'Gravel': 1.0},
        elevationProfile: [
          ElevationPoint(distanceKm: 0.0, elevationM: 1000.0, gradePercent: 4.0),
          ElevationPoint(distanceKm: 10.0, elevationM: 1600.0, gradePercent: 8.0),
        ],
        maneuvers: [],
        coordinates: [
          LatLng(48.000, 8.000),
          LatLng(48.100, 8.100),
        ],
      );

      final (midEle, midGrade) = TelemetryService.interpolateElevationAndGrade(
        customRoute.elevationProfile,
        5.0,
      );

      expect(midEle, closeTo(1300.0, 0.1));
      expect(midGrade, closeTo(6.0, 0.1));

      final remainingAscent = TelemetryService.computeRemainingAscent(
        customRoute.elevationProfile,
        5.0,
        midEle,
      );
      expect(remainingAscent, closeTo(300.0, 0.1));
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
