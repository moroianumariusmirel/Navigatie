import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trailpulse/app.dart';
import 'package:trailpulse/core/maps/osm_tile_providers.dart';

void main() {
  setUp(() {
    OsmTileProviders.overrideTileProvider = MockWhiteTileProvider();
  });

  testWidgets('TrailPulse Cockpit renders essential HUD and tactical bento tiles', (WidgetTester tester) async {
    await tester.pumpWidget(const TrailPulseApp());
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Brand Header
    expect(find.text('TRAILPULSE'), findsOneWidget);
    expect(find.text('TELEMETRY OS'), findsOneWidget);

    // Verify Turn Guidance Pill
    expect(find.text('140m'), findsOneWidget);
    expect(find.text('HAIRPIN LEFT'), findsOneWidget);

    // Verify Tactical Bento Grid Tiles
    expect(find.text('HEART RATE'), findsOneWidget);
    expect(find.text('SPEED'), findsOneWidget);
    expect(find.text('GRADE'), findsOneWidget);
    expect(find.text('CADENCE'), findsOneWidget);
    expect(find.text('ETA / REMAIN'), findsOneWidget);
    expect(find.text('OUTPUT POWER'), findsOneWidget);

    // Verify Elevation Slicer
    expect(find.text('ROUTE PROFILE & SLOPE SEVERITY'), findsOneWidget);

    // Verify 3 bottom buttons (HOLD TO PAUSE / RESUME, Flag, SOS) are completely removed
    expect(find.text('HOLD TO PAUSE'), findsNothing);
    expect(find.text('TAP TO RESUME'), findsNothing);
    expect(find.byIcon(Icons.flag), findsNothing);
    expect(find.byIcon(Icons.sos), findsNothing);

    // Verify Helper Note for Draggable Tiles
    expect(find.text('HOLD & DRAG ANY TILE TO REARRANGE COCKPIT'), findsOneWidget);

    // Verify ROUTE APEX is removed from the top banner
    expect(find.text('ROUTE APEX'), findsNothing);

    // Verify LIVE BIO-MECHANICAL MATRIX is removed
    expect(find.text('LIVE BIO-MECHANICAL MATRIX'), findsNothing);

    // Verify EDIT TILES button is present
    final editTilesBtn = find.byKey(const Key('cockpit_edit_tiles_button'));
    expect(editTilesBtn, findsOneWidget);

    // Verify Route Profile is present as a tile within the bento flow
    expect(find.byKey(const Key('metric_tile_route_profile')), findsOneWidget);

    // Verify Navigation Play/Pause and Hold-to-Stop Button (Initial State: Stopped / Play)
    final navButton = find.byKey(const Key('nav_play_pause_button'));
    expect(navButton, findsOneWidget);
    expect(find.text('HOLD TO STOP'), findsNothing);

    // Tap to Start Navigation (State 2: Active / Pause + 'HOLD TO STOP')
    await tester.tap(navButton);
    await tester.pump();
    expect(find.text('NAVIGATION ENGAGED • TELEMETRY ACTIVE'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.text('HOLD TO STOP'), findsOneWidget);

    // Tap to Pause Navigation (State 3: Paused / Resume + 'HOLD TO STOP')
    await tester.tap(navButton);
    await tester.pump();
    expect(find.text('NAVIGATION PAUSED • TELEMETRY STANDBY'), findsOneWidget);
    expect(find.text('HOLD TO STOP'), findsOneWidget);

    // Tap to Resume Navigation (Back to State 2: Active / Pause + 'HOLD TO STOP')
    await tester.tap(navButton);
    await tester.pump();
    expect(find.text('NAVIGATION ENGAGED • TELEMETRY ACTIVE'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.text('HOLD TO STOP'), findsOneWidget);

    // Long Press to Stop Navigation (Back to State 1: Stopped / Play)
    await tester.longPress(navButton);
    await tester.pump();
    expect(find.text('NAVIGATION STOPPED • PROGRESS RESET'), findsOneWidget);
    expect(find.text('HOLD TO STOP'), findsNothing);

    // Wait for SnackBars or clear them so they don't occlude other elements
    ScaffoldMessenger.of(tester.element(find.byType(Scaffold).first)).clearSnackBars();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Tactical GPS Sensor status badge
    expect(find.textContaining('GPS'), findsWidgets);

    // Verify long-press draggable metric tiles can swap places
    final speedTile = find.byKey(const Key('metric_tile_speed'));
    final hrTile = find.byKey(const Key('metric_tile_heart_rate'));
    expect(speedTile, findsOneWidget);
    expect(hrTile, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(speedTile));
    await tester.pump(const Duration(milliseconds: 350));
    await gesture.moveTo(tester.getCenter(hrTile));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify both tiles are still present in the reordered grid
    expect(find.byKey(const Key('metric_tile_speed')), findsOneWidget);
    expect(find.byKey(const Key('metric_tile_heart_rate')), findsOneWidget);

    // Scroll to and test EDIT TILES customizer modal bottom sheet
    await tester.ensureVisible(editTilesBtn);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(editTilesBtn);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('CUSTOMIZE COCKPIT TILES'), findsOneWidget);
    expect(find.textContaining('ACTIVE'), findsWidgets);

    // Toggle off Heart Rate tile
    final hrToggle = find.byKey(const Key('toggle_tile_heartRate'));
    expect(hrToggle, findsOneWidget);
    await tester.ensureVisible(hrToggle);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(hrToggle);
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Heart Rate tile was removed from cockpit
    expect(find.byKey(const Key('metric_tile_heart_rate')), findsNothing);

    // Toggle Heart Rate tile back on
    await tester.tap(hrToggle);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('metric_tile_heart_rate')), findsOneWidget);

    // Close the customizer modal
    final closeBtn = find.byKey(const Key('cockpit_close_customizer_button'));
    expect(closeBtn, findsOneWidget);
    await tester.tap(closeBtn);
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Verify Route Profile tile can be dragged to reorder
    final routeProfileTile = find.byKey(const Key('metric_tile_route_profile'));
    expect(routeProfileTile, findsOneWidget);
    await tester.ensureVisible(routeProfileTile);
    await tester.pump(const Duration(milliseconds: 200));

    final rpGesture = await tester.startGesture(tester.getCenter(routeProfileTile));
    await tester.pump(const Duration(milliseconds: 350));
    await rpGesture.moveTo(tester.getCenter(find.byKey(const Key('metric_tile_speed'))));
    await tester.pump(const Duration(milliseconds: 100));
    await rpGesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('metric_tile_route_profile')), findsOneWidget);
    expect(find.byKey(const Key('metric_tile_speed')), findsOneWidget);

    // Test RESET order button
    final resetBtn = find.byKey(const Key('cockpit_reset_tiles_button'));
    if (resetBtn.evaluate().isNotEmpty) {
      await tester.ensureVisible(resetBtn);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(resetBtn);
      await tester.pump(const Duration(milliseconds: 300));
    }
  });
}
