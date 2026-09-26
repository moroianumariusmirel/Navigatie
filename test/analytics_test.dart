import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trailpulse/core/models/route_model.dart';
import 'package:trailpulse/core/models/elevation_point.dart';
import 'package:trailpulse/core/models/activity_type.dart';
import 'package:trailpulse/core/telemetry/telemetry_service.dart';
import 'package:trailpulse/ui/analytics/analytics_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Slope Gradient Distribution & Session Summary Tests', () {
    test('computeSlopeDistribution accurately categorizes profile into 4 slope zones', () {
      final sampleRoute = RouteModel.sampleSchauinsland();
      final dist = TelemetryService.computeSlopeDistribution(
        sampleRoute.elevationProfile,
        sampleRoute.totalDistanceKm,
      );

      // Verify all 4 zones are represented
      expect(dist.flatRollersPercentage, greaterThan(0.0));
      expect(dist.moderateClimbPercentage, greaterThan(0.0));
      expect(dist.steepAlpinePercentage, greaterThan(0.0));
      expect(dist.extremeWallPercentage, greaterThan(0.0));

      expect(dist.flatRollersKm, greaterThan(0.0));
      expect(dist.moderateClimbKm, greaterThan(0.0));
      expect(dist.steepAlpineKm, greaterThan(0.0));
      expect(dist.extremeWallKm, greaterThan(0.0));

      // Percentages sum to 1.0 (100%)
      final totalPct = dist.flatRollersPercentage +
          dist.moderateClimbPercentage +
          dist.steepAlpinePercentage +
          dist.extremeWallPercentage;
      expect((totalPct - 1.0).abs(), lessThan(0.01));

      // Total distance matches
      final totalKm = dist.flatRollersKm +
          dist.moderateClimbKm +
          dist.steepAlpineKm +
          dist.extremeWallKm;
      expect((totalKm - sampleRoute.totalDistanceKm).abs(), lessThan(0.1));
    });

    test('computeSlopeDistribution returns empty on empty profile', () {
      final emptyDist = TelemetryService.computeSlopeDistribution([], 0.0);
      expect(emptyDist.flatRollersPercentage, equals(0.0));
      expect(emptyDist.totalDistanceKm, equals(0.0));
    });

    test('computeClimbedSoFar accurately computes elevation gained up to distance', () {
      final sampleRoute = RouteModel.sampleSchauinsland();
      final profile = sampleRoute.elevationProfile;

      expect(TelemetryService.computeClimbedSoFar(profile, 0.0), equals(0.0));

      final climbedAt24Km = TelemetryService.computeClimbedSoFar(profile, 24.1);
      expect(climbedAt24Km, greaterThan(500.0));

      final climbedAtApex = TelemetryService.computeClimbedSoFar(profile, 35.0);
      expect(climbedAtApex, greaterThan(climbedAt24Km));

      // On descent past 35km, climb does not increase
      final climbedAtEnd = TelemetryService.computeClimbedSoFar(profile, 42.5);
      expect(climbedAtEnd, equals(climbedAtApex));
    });

    test('TelemetryService stopNavigation populates lastSessionSummary with valid metrics', () {
      final telemetryService = TelemetryService(
        initialRoute: RouteModel.sampleSchauinsland(),
        autoStartSimulation: false,
      );

      // Initially null before navigation stop
      expect(telemetryService.lastSessionSummary, isNull);

      telemetryService.startNavigation();
      expect(telemetryService.isNavigating, isTrue);

      telemetryService.stopNavigation();
      expect(telemetryService.isNavigating, isFalse);

      final summary = telemetryService.lastSessionSummary;
      expect(summary, isNotNull);
      expect(summary!.totalClimbM, greaterThan(0.0));
      expect(summary.avgSpeedKmH, greaterThan(0.0));
      expect(summary.totalDuration, greaterThan(Duration.zero));
      expect(summary.formattedDuration, isNotEmpty);
    });

    testWidgets('AnalyticsScreen displays both Top and Bottom rows and dynamic slope distribution',
        (tester) async {
      final telemetryService = TelemetryService(
        initialRoute: RouteModel.sampleSchauinsland(),
        autoStartSimulation: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TelemetryService>.value(
            value: telemetryService,
            child: const AnalyticsScreen(),
          ),
        ),
      );

      // Verify Header
      expect(find.text('TERRAIN & EXERTION ANALYTICS'), findsOneWidget);
      expect(find.text('SESSION SUMMARY'), findsOneWidget);

      // Verify Top Row labels (Live In-Flight)
      expect(find.text('LIVE IN-FLIGHT PROGRESS'), findsOneWidget);
      expect(find.text('CLIMBED SO FAR'), findsOneWidget);
      expect(find.text('ACTUAL ELEVATION'), findsOneWidget);
      expect(find.text('TIME TO FINISH'), findsOneWidget);

      // Verify Bottom Row labels (Completed Summary)
      expect(find.text('COMPLETED RIDE SUMMARY'), findsOneWidget);
      expect(find.text('TOTAL CLIMB'), findsOneWidget);
      expect(find.text('AVG SPEED'), findsOneWidget);
      expect(find.text('TOTAL TIME'), findsOneWidget);

      // Before stopping navigation, bottom row displays '--'
      expect(find.text('--'), findsWidgets);
      expect(find.text('POPULATED ON STOP'), findsOneWidget);

      // Verify Slope Gradient Distribution contains the 4 zones
      expect(find.text('SLOPE GRADIENT DISTRIBUTION'), findsOneWidget);
      expect(find.text('0 - 3% (Flat / Rollers)'), findsOneWidget);
      expect(find.text('4 - 7% (Moderate Climb)'), findsOneWidget);
      expect(find.text('8 - 12% (Steep Alpine)'), findsOneWidget);
      expect(find.text('15%+ (Extreme Wall)'), findsOneWidget);

      // Shows active route name
      expect(find.textContaining('Schauinsland Alpine Ridge Traverse'), findsOneWidget);

      // Now start and stop navigation to populate the bottom row
      telemetryService.startNavigation();
      await tester.pump();

      telemetryService.stopNavigation();
      await tester.pump();

      // Bottom row is now populated with real session values (no longer showing '--' for all 3)
      final summary = telemetryService.lastSessionSummary;
      expect(summary, isNotNull);
      expect(find.text('+${summary!.totalClimbM.toInt()}m'), findsOneWidget);
      expect(find.text('${summary.avgSpeedKmH.toStringAsFixed(1)} km/h'), findsOneWidget);
      expect(find.text(summary.formattedDuration), findsOneWidget);
      expect(find.text('STOPPED • SAVED'), findsOneWidget);
    });

    testWidgets('AnalyticsScreen dynamically syncs with newly loaded GPX route', (tester) async {
      final telemetryService = TelemetryService(
        initialRoute: RouteModel.sampleSchauinsland(),
        autoStartSimulation: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TelemetryService>.value(
            value: telemetryService,
            child: const AnalyticsScreen(),
          ),
        ),
      );

      expect(find.textContaining('Schauinsland'), findsOneWidget);

      // Switch to Feldberg Hike route
      telemetryService.updateActiveRoute(RouteModel.sampleFeldbergHike());
      await tester.pump();

      expect(find.textContaining('Feldberg Cirque & Alpine Ridge Trek'), findsOneWidget);
      expect(find.textContaining('18.2 km'), findsOneWidget);
    });
  });
}
