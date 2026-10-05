import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:trailpulse/core/maps/trailpulse_vector_themes.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;
import 'package:vector_tile_renderer/src/tileset.dart' as vtr_tileset;
import 'package:vector_tile_renderer/src/tile_source.dart' as vtr_source;
import 'package:vector_tile_renderer/src/model/tile_model.dart' as vtr_model;
import 'package:vector_tile_renderer/src/model/geometry_model.dart' as vtr_geom;

void main() {
  group('TrailPulseVectorThemes Tests', () {
    test('outdoorLight theme compiles successfully and defines all key navigation layers', () {
      final theme = TrailPulseVectorThemes.outdoorLight();
      expect(theme, isNotNull);
      expect(theme.layers.length, greaterThanOrEqualTo(15));

      final layerIds = theme.layers.map((l) => l.id).toSet();

      // Background & Terrain
      expect(layerIds.contains('tp_background'), isTrue);
      expect(layerIds.contains('tp_earth'), isTrue);
      expect(layerIds.contains('tp_landuse_nature'), isTrue);
      expect(layerIds.contains('tp_water'), isTrue);
      expect(layerIds.contains('tp_water_lines'), isTrue);

      // Roads Hierarchy
      expect(layerIds.contains('tp_roads_highway'), isTrue);
      expect(layerIds.contains('tp_roads_highway_casing'), isTrue);
      expect(layerIds.contains('tp_roads_major'), isTrue);
      expect(layerIds.contains('tp_roads_major_casing'), isTrue);
      expect(layerIds.contains('tp_roads_minor'), isTrue);
      expect(layerIds.contains('tp_roads_minor_casing'), isTrue);
      expect(layerIds.contains('tp_roads_cycleway'), isTrue);
      expect(layerIds.contains('tp_roads_track'), isTrue);
      expect(layerIds.contains('tp_roads_path'), isTrue);

      // Labels
      expect(layerIds.contains('tp_places'), isTrue);
      expect(layerIds.contains('tp_roads_labels'), isTrue);
    });

    test('tacticalDark theme compiles successfully and defines high-contrast layers', () {
      final darkTheme = TrailPulseVectorThemes.tacticalDark();
      expect(darkTheme, isNotNull);
      expect(darkTheme.layers.length, greaterThanOrEqualTo(7));

      final layerIds = darkTheme.layers.map((l) => l.id).toSet();
      expect(layerIds.contains('tp_dark_background'), isTrue);
      expect(layerIds.contains('tp_dark_earth'), isTrue);
      expect(layerIds.contains('tp_dark_roads_minor'), isTrue);
      expect(layerIds.contains('tp_dark_roads_major'), isTrue);
      expect(layerIds.contains('tp_dark_roads_highway'), isTrue);
    });

    test('outdoorLight caches instances in memory', () {
      final t1 = TrailPulseVectorThemes.outdoorLight();
      final t2 = TrailPulseVectorThemes.outdoorLight();
      expect(identical(t1, t2), isTrue);
    });

    test('outdoorLight renders into PictureRecorder without crashing', () async {
      final theme = TrailPulseVectorThemes.outdoorLight();

      // Create a synthetic tile with major and minor road features
      final tileModel = vtr_model.Tile(layers: [
        vtr_model.TileLayer(
          name: 'roads',
          extent: 4096,
          features: [
            vtr_model.TileFeature(
              type: vtr_model.TileFeatureType.linestring,
              properties: {'kind': 'major_road', 'name': 'DN1'},
              lines: [
                vtr_geom.TileLine([
                  const Point<double>(0.0, 0.0),
                  const Point<double>(4096.0, 4096.0),
                ])
              ],
              points: null,
              polygons: null,
            ),
            vtr_model.TileFeature(
              type: vtr_model.TileFeatureType.linestring,
              properties: {'kind': 'minor_road', 'name': 'Strada Lunga'},
              lines: [
                vtr_geom.TileLine([
                  const Point<double>(0.0, 2048.0),
                  const Point<double>(4096.0, 2048.0),
                ])
              ],
              points: null,
              polygons: null,
            ),
          ],
        ),
      ]);

      final tileset = vtr_tileset.Tileset({'protomaps': tileModel});
      final tileSource = vtr_source.TileSource(tileset: tileset);

      final renderer = vtr.Renderer(theme: theme);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Verify rendering at zoom 12 (Romania Master level)
      renderer.render(canvas, tileSource, zoom: 12.0, rotation: 0.0, zoomScaleFactor: 1.0);
      final pic = recorder.endRecording();
      final img = await pic.toImage(256, 256);
      expect(img.width, equals(256));
      expect(img.height, equals(256));
    });
  });
}
