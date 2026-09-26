import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:trailpulse/core/models/activity_type.dart';
import 'package:trailpulse/core/models/explore_mode.dart';
import 'package:trailpulse/core/models/route_model.dart';
import 'package:trailpulse/core/routing/gpx_parser.dart';
import 'package:trailpulse/core/routing/osm_routing_service.dart';
import 'package:trailpulse/core/telemetry/telemetry_service.dart';
import 'package:trailpulse/core/maps/osm_tile_providers.dart';
import 'package:trailpulse/ui/planner/planner_screen.dart';

void main() {
  setUp(() {
    OsmTileProviders.overrideTileProvider = MockWhiteTileProvider();
  });

  group('GpxParser Unit Tests', () {
    const sampleGpxXml = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="TrailPulse Test" xmlns="http://www.topografix.com/GPX/1/1">
  <metadata>
    <name>Alpine Ridge Test Track</name>
  </metadata>
  <trk>
    <name>Schauinsland Test</name>
    <trkseg>
      <trkpt lat="47.912" lon="7.898">
        <ele>1200.0</ele>
      </trkpt>
      <trkpt lat="47.915" lon="7.905">
        <ele>1350.0</ele>
      </trkpt>
      <trkpt lat="47.920" lon="7.912">
        <ele>1450.0</ele>
      </trkpt>
      <trkpt lat="47.925" lon="7.918">
        <ele>1300.0</ele>
      </trkpt>
    </trkseg>
  </trk>
  <wpt lat="47.912" lon="7.898">
    <ele>1200.0</ele>
    <name>Trailhead Depot</name>
  </wpt>
</gpx>''';

    test('Parses GPX XML and computes elevation, ascent, descent, and distance', () {
      final route = GpxParser.parseGpx(sampleGpxXml, defaultActivity: ActivityType.cycling);

      expect(route.name, equals('Alpine Ridge Test Track'));
      expect(route.activityType, equals(ActivityType.cycling));
      expect(route.totalDistanceKm, greaterThan(1.0));
      expect(route.totalAscentM, equals(250.0)); // 1200 -> 1350 (+150), 1350 -> 1450 (+100) = 250
      expect(route.totalDescentM, equals(150.0)); // 1450 -> 1300 = 150
      expect(route.maxElevationM, equals(1450.0));
      expect(route.minElevationM, equals(1200.0));
      expect(route.waypoints.isNotEmpty, isTrue);
      expect(route.waypoints.first.title, equals('Trailhead Depot'));
    });

    test('Exports RouteModel to valid GPX XML and parses back accurately', () {
      final sampleRoute = RouteModel.sampleSchauinsland();
      final exportedGpx = GpxParser.exportToGpx(sampleRoute);

      expect(exportedGpx, contains('<?xml version="1.0" encoding="UTF-8"?>'));
      expect(exportedGpx, contains('<gpx version="1.1"'));
      expect(exportedGpx, contains('<name>${sampleRoute.name}</name>'));
      expect(exportedGpx, contains('<trkpt'));

      final reParsedRoute = GpxParser.parseGpx(exportedGpx);
      expect(reParsedRoute.name, equals(sampleRoute.name));
      expect(reParsedRoute.coordinates.length, equals(sampleRoute.coordinates.length));
      expect(reParsedRoute.totalDistanceKm, greaterThan(20.0));
    });

    test('Parses GeoJSON LineString into valid RouteModel', () {
      const sampleGeoJson = '''{
        "type": "FeatureCollection",
        "features": [
          {
            "type": "Feature",
            "properties": { "name": "Forest Loop GeoJSON" },
            "geometry": {
              "type": "LineString",
              "coordinates": [
                [7.898, 47.912, 1000.0],
                [7.905, 47.915, 1150.0],
                [7.912, 47.920, 1080.0]
              ]
            }
          }
        ]
      }''';

      final route = GpxParser.parseGeoJson(sampleGeoJson, defaultActivity: ActivityType.hiking);

      expect(route.name, equals('Forest Loop GeoJSON'));
      expect(route.activityType, equals(ActivityType.hiking));
      expect(route.totalAscentM, equals(150.0));
      expect(route.totalDescentM, equals(70.0));
      expect(route.maxElevationM, equals(1150.0));
      expect(route.minElevationM, equals(1000.0));
    });
  });

  group('PlannerScreen Activity Toggle & UI Widget Tests', () {
    testWidgets('Toggles between Cycling and Hiking modes', (WidgetTester tester) async {
      final telemetryService = TelemetryService(autoStartSimulation: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<TelemetryService>.value(
          value: telemetryService,
          child: const MaterialApp(
            home: PlannerScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Initial state is Cycling
      expect(find.text('CYCLING'), findsWidgets);
      expect(find.text('HIKING'), findsOneWidget);
      expect(find.text('LOAD GPX'), findsOneWidget);
      expect(find.text('CYCLOSM • CYCLE TRACKS'), findsOneWidget);

      // Tap the HIKING toggle button
      await tester.tap(find.text('HIKING'));
      await tester.pump(const Duration(milliseconds: 200));

      // Active mode should now switch to Hiking
      expect(telemetryService.activityType, equals(ActivityType.hiking));
      expect(find.text('OPENTOPOMAP • TOPO CONTOURS'), findsOneWidget);

      // Tap DETAILS to verify hiking route details
      await tester.tap(find.text('DETAILS'));
      await tester.pumpAndSettle();

      expect(find.text('ALPINE TREK / HIKING'), findsOneWidget);
      expect(find.text('FOOTING & TERRAIN BREAKDOWN'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      // Tap the CYCLING toggle button to switch back
      await tester.tap(find.text('CYCLING').first);
      await tester.pump(const Duration(milliseconds: 200));

      expect(telemetryService.activityType, equals(ActivityType.cycling));
      expect(find.text('CYCLOSM • CYCLE TRACKS'), findsOneWidget);
    });

    testWidgets('Tapping LOAD GPX opens Route Loader Modal and displays saved files list', (WidgetTester tester) async {
      final telemetryService = TelemetryService(autoStartSimulation: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<TelemetryService>.value(
          value: telemetryService,
          child: const MaterialApp(
            home: PlannerScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Tap LOAD GPX button
      await tester.tap(find.text('LOAD GPX'));
      await tester.pumpAndSettle();

      // Modal bottom sheet should be visible
      expect(find.text('IMPORT ROUTE / TRACK'), findsOneWidget);
      expect(find.text('SELECT GPX / ROUTE FILE'), findsOneWidget);
      expect(find.textContaining('MY SAVED FILES & ROUTES'), findsOneWidget);
      expect(find.text('OFFLINE READY'), findsOneWidget);
      expect(find.text('FAST TACTICAL PRESETS'), findsNothing);

      // Verify that saved routes list contains initial routes
      expect(find.text('Schauinsland Alpine Ridge Traverse'), findsOneWidget);

      // Tap a saved route tile to load it into the Planner
      await tester.tap(find.text('Schauinsland Alpine Ridge Traverse'));
      await tester.pumpAndSettle();

      // Verify route was activated in telemetry and loaded in Planner
      expect(telemetryService.activeRoute, isNotNull);
      expect(telemetryService.activeRoute!.name, contains('Schauinsland'));
    });

    testWidgets('RouteLoaderModal allows deleting a saved file from the list', (WidgetTester tester) async {
      final telemetryService = TelemetryService(autoStartSimulation: false);
      final initialCount = telemetryService.savedOfflineRoutes.length;

      await tester.pumpWidget(
        ChangeNotifierProvider<TelemetryService>.value(
          value: telemetryService,
          child: const MaterialApp(
            home: PlannerScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('LOAD GPX'));
      await tester.pumpAndSettle();

      expect(find.textContaining('MY SAVED FILES & ROUTES ($initialCount)'), findsOneWidget);

      // Tap the delete button on the first saved route
      final deleteBtnFinder = find.byTooltip('Delete file');
      expect(deleteBtnFinder, findsWidgets);
      await tester.tap(deleteBtnFinder.first);
      await tester.pumpAndSettle();

      // Count should be decremented
      expect(telemetryService.savedOfflineRoutes.length, equals(initialCount - 1));
      expect(find.textContaining('MY SAVED FILES & ROUTES (${initialCount - 1})'), findsOneWidget);
    });

    testWidgets('RouteLoaderModal allows pasting and parsing raw GPX track', (WidgetTester tester) async {
      final telemetryService = TelemetryService(autoStartSimulation: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<TelemetryService>.value(
          value: telemetryService,
          child: const MaterialApp(
            home: PlannerScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('LOAD GPX'));
      await tester.pumpAndSettle();

      // Scroll down and tap toggle to show raw paste area
      await tester.ensureVisible(find.text('PASTE RAW GPX / GEOJSON TEXT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PASTE RAW GPX / GEOJSON TEXT'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('PARSE & LOAD PASTED TRACK'), findsOneWidget);

      const pasteXml = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="TrailPulse Test">
  <trk>
    <name>Pasted Test Route</name>
    <trkseg>
      <trkpt lat="47.900" lon="7.850"><ele>500.0</ele></trkpt>
      <trkpt lat="47.910" lon="7.860"><ele>620.0</ele></trkpt>
    </trkseg>
  </trk>
</gpx>''';

      await tester.enterText(find.byType(TextField), pasteXml);
      await tester.ensureVisible(find.text('PARSE & LOAD PASTED TRACK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PARSE & LOAD PASTED TRACK'));
      await tester.pumpAndSettle();

      expect(telemetryService.activeRoute, isNotNull);
      expect(telemetryService.activeRoute!.name, equals('Pasted Test Route'));
    });

    testWidgets('Tapping on map sets Start (A) and Arrival (B), manages stops, saves route, and starts in Cockpit', (WidgetTester tester) async {
      final telemetryService = TelemetryService(autoStartSimulation: false);
      telemetryService.setSelectedTabIndex(1); // Start on Planner tab

      await tester.pumpWidget(
        ChangeNotifierProvider<TelemetryService>.value(
          value: telemetryService,
          child: const MaterialApp(
            home: PlannerScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Initial state: Step 1 banner and bottom pinned buttons
      expect(find.text('STEP 1: TAP MAP TO SET START POINT (A)'), findsOneWidget);
      expect(find.text('START IN COCKPIT'), findsOneWidget);
      expect(find.text('SAVE ROUTE'), findsOneWidget);

      // Tap 1: Set Start Point (A)
      final mapFinder = find.byType(FlutterMap);
      expect(mapFinder, findsOneWidget);
      await tester.tapAt(tester.getCenter(mapFinder) + const Offset(-40, -40));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('STEP 2: TAP MAP TO SET ARRIVAL POINT (B)'), findsOneWidget);

      // Tap 2: Set Arrival Point (B) -> triggers route calculation
      await tester.tapAt(tester.getCenter(mapFinder) + const Offset(40, 40));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ROUTE ACTIVE • TAP TO ADD STOPS (0 STOPS)'), findsOneWidget);
      expect(find.text('DETAILS'), findsOneWidget);

      // Tap DETAILS to open Route Details & Waypoints bottom sheet
      await tester.tap(find.text('DETAILS'));
      await tester.pumpAndSettle();

      expect(find.text('ROUTE DETAILS & WAYPOINTS'), findsOneWidget);
      expect(find.text('ROUTE STOPS & WAYPOINTS (2)'), findsOneWidget);
      expect(find.text('Start Point (A)'), findsOneWidget);
      expect(find.text('Arrival Destination (B)'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();

      // Save Route
      await tester.tap(find.text('SAVE ROUTE'));
      await tester.pumpAndSettle();

      expect(find.text('SAVE ROUTE OFFLINE'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Freiburg Express Loop');
      await tester.tap(find.text('SAVE'));
      await tester.pumpAndSettle();

      // Check route saved and Explorer set to offline mode
      expect(telemetryService.savedOfflineRoutes.any((r) => r.name == 'Freiburg Express Loop'), isTrue);
      expect(telemetryService.savedOfflineRoutes.first.name, equals('Freiburg Express Loop'));
      expect(telemetryService.exploreMode, equals(ExploreMode.offline));

      // Start Navigation in Cockpit
      await tester.tap(find.text('START IN COCKPIT'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(telemetryService.selectedTabIndex, equals(2)); // Index 2 is Cockpit
      expect(telemetryService.activeRoute, isNotNull);
      expect(telemetryService.navigationState, equals(NavigationState.active));

      // Clean up navigation session
      telemetryService.stopNavigation();
    });

    testWidgets('RESET button removes currently loaded route from Planner map without affecting Cockpit activeRoute or saved offline routes', (WidgetTester tester) async {
      final sampleRoute = RouteModel.sampleSchauinsland();
      final telemetryService = TelemetryService(
        initialRoute: sampleRoute,
        autoStartSimulation: false,
      );
      final initialOfflineCount = telemetryService.savedOfflineRoutes.length;

      await tester.pumpWidget(
        ChangeNotifierProvider<TelemetryService>.value(
          value: telemetryService,
          child: const MaterialApp(
            home: PlannerScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // With initialRoute active, Planner map displays the route and RESET button
      expect(find.text('RESET'), findsWidgets);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.text('START IN COCKPIT'), findsOneWidget);

      // Tap RESET button
      final resetButtons = find.text('RESET');
      await tester.tap(resetButtons.first);
      await tester.pumpAndSettle();

      // Verify SnackBar confirmation
      expect(find.text('PLANNER MAP RESET • ROUTE REMOVED'), findsOneWidget);

      // Verify route was removed from Planner map viewport
      expect(find.byType(PolylineLayer), findsNothing);
      expect(find.text('MAP READY FOR ROUTE PLANNING'), findsOneWidget);
      expect(find.text('Tap map to set Start (A) & Destination (B)'), findsOneWidget);
      expect(find.text('START IN COCKPIT'), findsNothing);

      // CRITICAL: Verify Cockpit activeRoute is 100% UNTOUCHED
      expect(telemetryService.activeRoute, isNotNull);
      expect(telemetryService.activeRoute!.id, equals(sampleRoute.id));
      expect(telemetryService.activeRoute!.name, equals(sampleRoute.name));

      // CRITICAL: Verify offline routes are 100% UNTOUCHED
      expect(telemetryService.savedOfflineRoutes.length, equals(initialOfflineCount));

      // Verify user can now start planning a brand new route on the clean map
      final mapFinder = find.byType(FlutterMap);
      await tester.tapAt(tester.getCenter(mapFinder) + const Offset(-40, -40));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('STEP 2: TAP MAP TO SET ARRIVAL POINT (B)'), findsOneWidget);

      await tester.tapAt(tester.getCenter(mapFinder) + const Offset(40, 40));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('ROUTE ACTIVE • TAP TO ADD STOPS (0 STOPS)'), findsOneWidget);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.text('START IN COCKPIT'), findsOneWidget);
    });
  });

  group('OsmRoutingService Tests', () {
    test('calculateRoute generates valid route and elevation profile offline or online', () async {
      final points = [
        const LatLng(47.912, 7.898),
        const LatLng(47.915, 7.905),
        const LatLng(47.925, 7.918),
      ];

      final route = await OsmRoutingService.calculateRoute(
        points: points,
        activityType: ActivityType.cycling,
        customName: 'Black Forest Trail Test',
      );

      expect(route.name, equals('Black Forest Trail Test'));
      expect(route.activityType, equals(ActivityType.cycling));
      expect(route.coordinates.length, greaterThanOrEqualTo(3));
      expect(route.waypoints.length, equals(3));
      expect(route.waypoints.first.title, equals('Start Point'));
      expect(route.waypoints.last.title, equals('Arrival Destination'));
      expect(route.totalDistanceKm, greaterThan(0));
      expect(route.elevationProfile.isNotEmpty, isTrue);
    });
  });
}
