import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trailpulse/core/telemetry/telemetry_service.dart';
import 'package:trailpulse/core/maps/osm_tile_providers.dart';
import 'package:trailpulse/core/models/activity_type.dart';
import 'package:trailpulse/ui/explore/explore_screen.dart';

void main() {
  setUp(() {
    OsmTileProviders.overrideTileProvider = MockWhiteTileProvider();
  });

  testWidgets('ExploreScreen renders top activity toggle, online/offline switcher, and OSM traces', (WidgetTester tester) async {
    final telemetryService = TelemetryService(autoStartSimulation: false);

    await tester.pumpWidget(
      ChangeNotifierProvider<TelemetryService>.value(
        value: telemetryService,
        child: const MaterialApp(
          home: ExploreScreen(),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    // Verify top controls matching PlannerScreen
    expect(find.text('CYCLING'), findsWidgets);
    expect(find.text('HIKING'), findsOneWidget);
    expect(find.text('LOAD GPX'), findsOneWidget);

    // Verify Online vs Offline switcher
    expect(find.text('ONLINE OSM TRACES'), findsOneWidget);
    expect(find.text('OFFLINE SAVED'), findsOneWidget);

    // Verify online traces list is rendered
    expect(find.byType(TextField), findsOneWidget);
    expect(find.textContaining('Schauinsland Gravel King'), findsOneWidget);

    // Toggle to HIKING mode
    await tester.tap(find.text('HIKING'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(telemetryService.activityType, equals(ActivityType.hiking));
    expect(find.textContaining('Feldberg Cirque'), findsOneWidget);

    // Switch to OFFLINE SAVED tab
    await tester.tap(find.text('OFFLINE SAVED'));
    await tester.pump(const Duration(milliseconds: 100));

    // Verify offline section headers and saved routes
    expect(find.text('100% OFFLINE READY'), findsOneWidget);
    expect(find.text('REGIONAL OFFLINE MAP PACKAGES'), findsOneWidget);
    expect(find.textContaining('Black Forest & Schauinsland'), findsOneWidget);
  });
}
