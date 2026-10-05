import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

/// High-contrast vector map themes for TrailPulse navigation.
///
/// Designed specifically for outdoor cycling, mountain biking, gravel riding,
/// and hiking to ensure streets, trails, water bodies, and green areas are
/// rendered with vibrant clarity and high contrast.
class TrailPulseVectorThemes {
  TrailPulseVectorThemes._();

  static vtr.Theme? _cachedOutdoorLight;
  static vtr.Theme? _cachedTacticalDark;

  /// High-Contrast Outdoor Light Theme (CyclOSM / OpenStreetMap outdoor inspired).
  ///
  /// - Background & Earth: Warm outdoor parchment / clean light gray
  /// - Highways / Motorways: Vibrant orange (#FFA040) with amber borders
  /// - Major Roads: Bright primary yellow (#FFF275) with protective casing
  /// - Minor Roads / Streets: Crisp high-contrast white (#FFFFFF) with borders (zoom 10+)
  /// - Cycleways: Neon emerald green (#00C853)
  /// - Mountain Tracks & Gravel: Earth brown dashed lines (#8D6E63)
  /// - Hiking Paths & Singletrack: Deep amber dashed lines (#E65100)
  /// - Water bodies & Rivers: Navigation blue (#74B4E8 / #5B9FD6)
  /// - Forests & Parks: Soft outdoor lush green (#C8E6C9)
  /// - Places & Labels: Dark charcoal with crisp white protective halo
  static vtr.Theme outdoorLight({vtr.Logger? logger}) {
    if (_cachedOutdoorLight != null) return _cachedOutdoorLight!;
    final themeData = _buildOutdoorLightThemeData();
    _cachedOutdoorLight = vtr.ThemeReader(logger: logger).read(themeData);
    return _cachedOutdoorLight!;
  }

  /// Tactical OLED High-Contrast Dark Theme.
  ///
  /// Solves the pitch-black 1.2:1 contrast issue of stock dark themes by using
  /// high-luminance neon cyan, warm amber, and white roads on dark OLED slate.
  static vtr.Theme tacticalDark({vtr.Logger? logger}) {
    if (_cachedTacticalDark != null) return _cachedTacticalDark!;
    final themeData = _buildTacticalDarkThemeData();
    _cachedTacticalDark = vtr.ThemeReader(logger: logger).read(themeData);
    return _cachedTacticalDark!;
  }

  static Map<String, dynamic> _buildOutdoorLightThemeData() {
    return {
      "version": 8,
      "sources": {
        "protomaps": {
          "type": "vector",
          "attribution": "Protomaps © OpenStreetMap contributors",
        }
      },
      "layers": [
        // 1. Background Canvas
        {
          "id": "tp_background",
          "type": "background",
          "paint": {
            "background-color": "#DCE3D4",
          }
        },
        // 2. Earth / Terrain Fill
        {
          "id": "tp_earth",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "earth",
          "paint": {
            "fill-color": "#F8F9F5",
          }
        },
        // 2b. Low-to-Mid Zoom Landcover (z0-z8 forests, farmlands, meadows, nature)
        {
          "id": "tp_landcover",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "landcover",
          "maxzoom": 9,
          "filter": [
            "any",
            ["in", "kind", "forest", "farmland", "grassland", "scrub", "glacier", "barren"]
          ],
          "paint": {
            "fill-color": "#D2E8D2",
            "fill-opacity": 0.80,
          }
        },
        // 2c. Natural Areas (woods, heath, nature reserves)
        {
          "id": "tp_natural",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "natural",
          "filter": [
            "any",
            ["in", "kind", "wood", "scrub", "heath", "grassland", "bare_rock", "scree"]
          ],
          "paint": {
            "fill-color": "#C8E6C9",
            "fill-opacity": 0.80,
          }
        },
        // 3. Nature / Parks / Forests
        {
          "id": "tp_landuse_nature",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "landuse",
          "filter": [
            "any",
            ["in", "kind", "park", "forest", "nature_reserve", "protected_area", "national_park", "wood", "grass", "meadow", "garden", "allotments"]
          ],
          "paint": {
            "fill-color": "#C8E6C9",
            "fill-opacity": 0.85,
          }
        },
        // 4. Urban Built-up Areas
        {
          "id": "tp_landuse_urban",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "landuse",
          "filter": [
            "any",
            ["in", "kind", "residential", "suburb", "neighbourhood", "urban"]
          ],
          "paint": {
            "fill-color": "#EAECE4",
            "fill-opacity": 0.65,
          }
        },
        // 5. Water Bodies (Lakes, reservoirs, sea)
        {
          "id": "tp_water",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "water",
          "paint": {
            "fill-color": "#74B4E8",
          }
        },
        // 6. Waterways (Rivers, canals, streams) - linear features only
        {
          "id": "tp_water_lines",
          "type": "line",
          "source": "protomaps",
          "source-layer": "water",
          "filter": [
            "any",
            ["in", "kind", "river", "canal", "stream", "ditch", "drain"]
          ],
          "paint": {
            "line-color": "#5B9FD6",
            "line-width": [
              "interpolate", ["exponential", 1.5], ["zoom"],
              6, 0.6,
              10, 1.8,
              14, 3.8,
              18, 6.0
            ]
          }
        },
        // 7. Boundaries (Country & Regional borders)
        {
          "id": "tp_boundaries",
          "type": "line",
          "source": "protomaps",
          "source-layer": "boundaries",
          "paint": {
            "line-color": "#A0A898",
            "line-width": 1.2,
            "line-dasharray": [4, 3],
          }
        },
        // 7b. Topographic Elevation Contours (20m, 50m, 100m)
        {
          "id": "tp_contours_20m",
          "type": "line",
          "source": "protomaps",
          "source-layer": "contours",
          "minzoom": 12,
          "paint": {
            "line-color": "#D7CCC8",
            "line-width": 0.6,
          }
        },
        {
          "id": "tp_contours_50m",
          "type": "line",
          "source": "protomaps",
          "source-layer": "contours",
          "minzoom": 11,
          "paint": {
            "line-color": "#BCAAA4",
            "line-width": 0.9,
          }
        },
        {
          "id": "tp_contours_100m",
          "type": "line",
          "source": "protomaps",
          "source-layer": "contours",
          "minzoom": 10,
          "paint": {
            "line-color": "#8D6E63",
            "line-width": 1.3,
          }
        },
        {
          "id": "tp_contours_labels",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "contours",
          "minzoom": 12,
          "filter": ["has", "ele"],
          "layout": {
            "text-field": ["concat", ["get", "ele"], "m"],
            "text-size": 9,
            "text-font": ["Noto Sans Regular"],
          },
          "paint": {
            "text-color": "#6D4C41",
            "text-halo-color": "#FFFFFF",
            "text-halo-width": 1.2,
          }
        },
        // 8. Railways
        {
          "id": "tp_roads_rail",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "minzoom": 11,
          "filter": ["==", "kind", "rail"],
          "paint": {
            "line-color": "#757575",
            "line-width": 1.5,
            "line-dasharray": [3, 3],
          }
        },
        // 9. Minor Roads Casing (Local streets, residential)
        {
          "id": "tp_roads_minor_casing",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "minzoom": 10,
          "filter": [
            "all",
            ["==", "kind", "minor_road"],
            ["!in", "kind_detail", "service", "track", "path", "cycleway", "footway"]
          ],
          "paint": {
            "line-color": "#CBD0C6",
            "line-width": [
              "interpolate", ["exponential", 1.5], ["zoom"],
              10, 1.6,
              12, 2.8,
              14, 4.8,
              18, 12.0
            ]
          }
        },
        // 10. Minor Roads Core (Pure white streets)
        {
          "id": "tp_roads_minor",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "minzoom": 10,
          "filter": [
            "all",
            ["==", "kind", "minor_road"],
            ["!in", "kind_detail", "service", "track", "path", "cycleway", "footway"]
          ],
          "paint": {
            "line-color": "#FFFFFF",
            "line-width": [
              "interpolate", ["exponential", 1.5], ["zoom"],
              10, 0.8,
              12, 1.8,
              14, 3.5,
              18, 9.0
            ]
          }
        },
        // 11. Major Roads Casing (Primary, Secondary, Tertiary)
        {
          "id": "tp_roads_major_casing",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "filter": ["==", "kind", "major_road"],
          "paint": {
            "line-color": "#C4BC88",
            "line-width": [
              "interpolate", ["exponential", 1.5], ["zoom"],
              6, 2.0,
              10, 3.6,
              12, 4.8,
              14, 7.0,
              18, 16.0
            ]
          }
        },
        // 12. Major Roads Core (Bright Yellow)
        {
          "id": "tp_roads_major",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "filter": ["==", "kind", "major_road"],
          "paint": {
            "line-color": "#FFF275",
            "line-width": [
              "interpolate", ["exponential", 1.5], ["zoom"],
              6, 1.2,
              10, 2.4,
              12, 3.2,
              14, 5.2,
              18, 13.0
            ]
          }
        },
        // 13. Highways / Motorways Casing
        {
          "id": "tp_roads_highway_casing",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "filter": ["==", "kind", "highway"],
          "paint": {
            "line-color": "#CC7000",
            "line-width": [
              "interpolate", ["exponential", 1.5], ["zoom"],
              5, 2.4,
              8, 4.2,
              12, 6.5,
              14, 8.5,
              18, 18.0
            ]
          }
        },
        // 14. Highways / Motorways Core (Vibrant Orange)
        {
          "id": "tp_roads_highway",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "filter": ["==", "kind", "highway"],
          "paint": {
            "line-color": "#FFA040",
            "line-width": [
              "interpolate", ["exponential", 1.5], ["zoom"],
              5, 1.4,
              8, 2.6,
              12, 4.4,
              14, 6.5,
              18, 15.0
            ]
          }
        },
        // 15. Gravel & Agricultural Tracks (Earth brown dashed)
        {
          "id": "tp_roads_track",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "minzoom": 11,
          "filter": ["==", "kind_detail", "track"],
          "paint": {
            "line-color": "#8D6E63",
            "line-width": [
              "interpolate", ["linear"], ["zoom"],
              11, 1.2,
              14, 2.2,
              18, 4.0
            ],
            "line-dasharray": [3, 2],
          }
        },
        // 16. Hiking Trails & Footpaths (Deep amber dashed)
        {
          "id": "tp_roads_path",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "minzoom": 11,
          "filter": [
            "any",
            ["in", "kind_detail", "path", "footway", "pedestrian"]
          ],
          "paint": {
            "line-color": "#E65100",
            "line-width": [
              "interpolate", ["linear"], ["zoom"],
              11, 1.2,
              14, 2.2,
              18, 3.5
            ],
            "line-dasharray": [2, 2],
          }
        },
        // 17. Cycleways & Bike Trails (Neon Green)
        {
          "id": "tp_roads_cycleway",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "minzoom": 10,
          "filter": ["==", "kind_detail", "cycleway"],
          "paint": {
            "line-color": "#00C853",
            "line-width": [
              "interpolate", ["exponential", 1.5], ["zoom"],
              10, 1.6,
              12, 2.6,
              14, 4.2,
              18, 6.5
            ]
          }
        },
        // 18. Place Labels (Towns, Cities, Localities)
        {
          "id": "tp_places",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "places",
          "filter": [
            "any",
            ["in", "kind", "country", "region", "city", "town", "locality", "village"]
          ],
          "layout": {
            "text-field": ["get", "name"],
            "text-size": [
              "interpolate", ["linear"], ["zoom"],
              6, 11,
              10, 13,
              14, 16
            ],
            "text-font": ["Noto Sans Bold"],
          },
          "paint": {
            "text-color": "#212529",
            "text-halo-color": "#FFFFFF",
            "text-halo-width": 2.0,
          }
        },
        // 19. Road Labels
        {
          "id": "tp_roads_labels",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "roads",
          "minzoom": 11,
          "filter": ["has", "name"],
          "layout": {
            "text-field": ["get", "name"],
            "text-size": [
              "interpolate", ["linear"], ["zoom"],
              11, 9,
              14, 12,
              18, 14
            ],
          },
          "paint": {
            "text-color": "#374151",
            "text-halo-color": "#FFFFFF",
            "text-halo-width": 1.5,
          }
        },
        // 20. Mountain Peaks, Summits & Elevation Badges
        {
          "id": "tp_mountain_peaks",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "pois",
          "filter": [
            "any",
            ["in", "kind", "peak", "volcano"]
          ],
          "layout": {
            "text-field": [
              "case",
              ["has", "elevation"],
              ["concat", "▲ ", ["get", "name"], " ", ["get", "elevation"], "m"],
              ["has", "ele"],
              ["concat", "▲ ", ["get", "name"], " ", ["get", "ele"], "m"],
              ["concat", "▲ ", ["get", "name"]]
            ],
            "text-size": [
              "interpolate", ["linear"], ["zoom"],
              9, 10,
              12, 12,
              15, 14
            ],
            "text-font": ["Noto Sans Bold"],
          },
          "paint": {
            "text-color": "#4E342E",
            "text-halo-color": "#FFFFFF",
            "text-halo-width": 2.0,
          }
        },
        // 21. Scenic Viewpoints
        {
          "id": "tp_viewpoints",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "pois",
          "minzoom": 11,
          "filter": ["==", "kind", "viewpoint"],
          "layout": {
            "text-field": [
              "case",
              ["has", "name"],
              ["concat", "👁 ", ["get", "name"]],
              "👁 Viewpoint"
            ],
            "text-size": 11,
            "text-font": ["Noto Sans Regular"],
          },
          "paint": {
            "text-color": "#00695C",
            "text-halo-color": "#FFFFFF",
            "text-halo-width": 1.5,
          }
        },
        // 22. Alpine Huts, Mountain Shelters & Bivouacs
        {
          "id": "tp_mountain_huts",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "pois",
          "minzoom": 10,
          "filter": [
            "any",
            ["in", "kind", "alpine_hut", "wilderness_hut", "shelter", "camp_site"]
          ],
          "layout": {
            "text-field": [
              "case",
              ["has", "name"],
              ["concat", "🛖 ", ["get", "name"]],
              "🛖 Refuge"
            ],
            "text-size": 11,
            "text-font": ["Noto Sans Bold"],
          },
          "paint": {
            "text-color": "#880E4F",
            "text-halo-color": "#FFFFFF",
            "text-halo-width": 1.8,
          }
        }
      ]
    };
  }

  static Map<String, dynamic> _buildTacticalDarkThemeData() {
    return {
      "version": 8,
      "sources": {
        "protomaps": {
          "type": "vector",
          "attribution": "Protomaps © OpenStreetMap contributors",
        }
      },
      "layers": [
        {
          "id": "tp_dark_background",
          "type": "background",
          "paint": {"background-color": "#0B1326"}
        },
        {
          "id": "tp_dark_earth",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "earth",
          "paint": {"fill-color": "#111A2E"}
        },
        {
          "id": "tp_dark_landcover",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "landcover",
          "maxzoom": 9,
          "filter": [
            "any",
            ["in", "kind", "forest", "farmland", "grassland", "scrub", "glacier", "barren"]
          ],
          "paint": {"fill-color": "#132E24", "fill-opacity": 0.8}
        },
        {
          "id": "tp_dark_water",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "water",
          "paint": {"fill-color": "#1B3A5B"}
        },
        {
          "id": "tp_dark_water_lines",
          "type": "line",
          "source": "protomaps",
          "source-layer": "water",
          "filter": [
            "any",
            ["in", "kind", "river", "canal", "stream", "ditch"]
          ],
          "paint": {
            "line-color": "#2563EB",
            "line-width": 1.5
          }
        },
        {
          "id": "tp_dark_landuse_nature",
          "type": "fill",
          "source": "protomaps",
          "source-layer": "landuse",
          "filter": [
            "any",
            ["in", "kind", "park", "forest", "nature_reserve", "protected_area"]
          ],
          "paint": {"fill-color": "#143026", "fill-opacity": 0.8}
        },
        {
          "id": "tp_dark_contours_100m",
          "type": "line",
          "source": "protomaps",
          "source-layer": "contours",
          "minzoom": 10,
          "paint": {
            "line-color": "#475569",
            "line-width": 1.0
          }
        },
        {
          "id": "tp_dark_roads_minor",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "minzoom": 10,
          "filter": ["==", "kind", "minor_road"],
          "paint": {
            "line-color": "#8FA3BF",
            "line-width": 1.5,
          }
        },
        {
          "id": "tp_dark_roads_major",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "filter": ["==", "kind", "major_road"],
          "paint": {
            "line-color": "#FBBF24",
            "line-width": 2.5,
          }
        },
        {
          "id": "tp_dark_roads_highway",
          "type": "line",
          "source": "protomaps",
          "source-layer": "roads",
          "filter": ["==", "kind", "highway"],
          "paint": {
            "line-color": "#F97316",
            "line-width": 3.5,
          }
        },
        {
          "id": "tp_dark_places",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "places",
          "filter": ["in", "kind", "city", "town", "locality", "village"],
          "layout": {
            "text-field": ["get", "name"],
            "text-size": 13,
          },
          "paint": {
            "text-color": "#E2E8F0",
            "text-halo-color": "#0B1326",
            "text-halo-width": 1.5,
          }
        },
        {
          "id": "tp_dark_mountain_peaks",
          "type": "symbol",
          "source": "protomaps",
          "source-layer": "pois",
          "filter": ["any", ["in", "kind", "peak", "volcano"]],
          "layout": {
            "text-field": [
              "case",
              ["has", "elevation"],
              ["concat", "▲ ", ["get", "name"], " ", ["get", "elevation"], "m"],
              ["has", "ele"],
              ["concat", "▲ ", ["get", "name"], " ", ["get", "ele"], "m"],
              ["concat", "▲ ", ["get", "name"]]
            ],
            "text-size": 12,
            "text-font": ["Noto Sans Bold"]
          },
          "paint": {
            "text-color": "#38BDF8",
            "text-halo-color": "#0B1326",
            "text-halo-width": 2.0
          }
        }
      ]
    };
  }
}
