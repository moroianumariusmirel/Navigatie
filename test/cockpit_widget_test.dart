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

    // Verify Elevation Slicer and Actions
    expect(find.text('ROUTE PROFILE & SLOPE SEVERITY'), findsOneWidget);
    expect(find.text('HOLD TO PAUSE'), findsOneWidget);
  });
}
