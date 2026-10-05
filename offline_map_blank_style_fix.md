# Offline Map Rendering Fix & Mountain Elevation Architecture

**Status:** Plan & Design Complete. No app code has been modified.

---

## 1. Executive Summary

Following live testing on real downloaded vector tiles (`ro_bucegi_brasov.pmtiles`), we confirmed that:
1. **The downloaded vector tile data is intact:** It contains roads (highways, primary, secondary), landuse (forests, residential), water bodies, rivers, places, and buildings.
2. **No style file needs to be downloaded:** The style is built directly into the app code in `trailpulse_vector_themes.dart`.
3. **The blank / "river only" appearance is caused by:**
   - Earth `#F4F6F0` blending into background `#EBF0E6`.
   - Missing `landcover` and `natural` layers at zoom levels 0–8.
   - Waterway outlines being drawn heavily around all water polygons.
   - Low-zoom highways and major roads having very thin widths.
4. **Streets & Trails missing in country packs:** Country master packs were capped at `maxZoom: 12`, but residential roads, gravel tracks, and hiking paths in OpenStreetMap only exist at zoom 13–15.
5. **No mountains rendered:** Protomaps vector tiles contain no elevation contours, hillshade, or DEM, and the vector theme omitted mountain summits, viewpoints, and passes from the `pois` layer.

---

## 2. Combined Mountain Elevation Solution

To deliver a true outdoor topographic map offline, we combine **both** dimensions of mountain terrain:

```
┌─────────────────────────────────────────────────────────────────┐
│               TrailPulse Offline Map Layers                     │
├─────────────────────────────────────────────────────────────────┤
│ 6. POIs & Mountain Summits (▲ Vf. Omu 2505m, Babele, huts)     │
├─────────────────────────────────────────────────────────────────┤
│ 5. Roads, Streets, Cycleways & Hiking Singletrack               │
├─────────────────────────────────────────────────────────────────┤
│ 4. Topographic Elevation Contours (20m, 50m, 100m index lines)   │
├─────────────────────────────────────────────────────────────────┤
│ 3. Waterways & Rivers                                           │
├─────────────────────────────────────────────────────────────────┤
│ 2. Nature, Forests & Landcover (forests, meadows, grasslands)   │
├─────────────────────────────────────────────────────────────────┤
│ 1. Earth / Land Surface Fill                                    │
└─────────────────────────────────────────────────────────────────┘
```

### A. Mountain Peaks, Summits, Viewpoints & Huts
Directly rendered from the `pois` layer in the existing vector theme:
- **Summits (`kind == 'peak'`):** Peak marker `▲` with mountain name and elevation badge (e.g., `▲ Vf. Omu 2505 m`, `▲ Postăvaru 1799 m`, `▲ Babele 2292 m`).
- **Viewpoints (`kind == 'viewpoint'`):** Panoramic viewpoint icon and name.
- **Mountain Passes (`kind in ['saddle', 'mountain_pass']`):** Pass name and altitude.
- **Mountain Huts & Shelters (`kind in ['alpine_hut', 'wilderness_hut', 'shelter']`):** Alpine refuge markers for hikers and cyclists.

### B. Topographic Elevation Contours (20m, 50m, 100m)
- **Regular Contours (every 20m):** Thin, subtle lines (`#D7CCC8`, width 0.6px).
- **Intermediate Contours (every 50m):** Medium lines (`#BCAAA4`, width 0.9px).
- **Index Contours (every 100m):** Prominent lines (`#8D6E63`, width 1.3px) with altitude numbers along lines (`1200`, `1300`, `1400`, `2500m`).
- Packaged directly with the mountain regional packs (adding only ~8–14 MB per mountain region).

---

## 3. Code Modifications (Implementation Guide)

### Fix 1: Visual Contrast & Missing Layers in `trailpulse_vector_themes.dart`

```dart
// 1. Differentiate Canvas & Earth:
"tp_background": {"background-color": "#DCE3D4"},
"tp_earth": {"fill-color": "#F8F9F5"},

// 2. Add Landcover at Zoom 0-8 (Forests, farmland, meadows):
{
  "id": "tp_landcover",
  "type": "fill",
  "source": "protomaps",
  "source-layer": "landcover",
  "maxzoom": 9,
  "filter": ["any", ["in", "kind", "forest", "farmland", "grassland", "scrub", "glacier", "barren"]],
  "paint": {"fill-color": "#C8E6C9", "fill-opacity": 0.75}
},

// 3. Fix Waterlines to waterways only (prevent double-stroking lakes/seas):
{
  "id": "tp_water_lines",
  "type": "line",
  "source": "protomaps",
  "source-layer": "water",
  "filter": ["any", ["in", "kind", "river", "canal", "stream"]],
  "paint": {"line-color": "#5B9FD6", ...}
},

// 4. Low-zoom road visibility:
// Increase line-width for major_road and highway at zoom 6-10.

// 5. Mountain Peaks & Summits:
{
  "id": "tp_mountain_peaks",
  "type": "symbol",
  "source": "protomaps",
  "source-layer": "pois",
  "filter": ["==", "kind", "peak"],
  "layout": {
    "text-field": ["concat", "▲ ", ["get", "name"], " ", ["get", "elevation"], "m"],
    "text-size": ["interpolate", ["linear"], ["zoom"], 10, 10, 14, 13],
    "text-font": ["Noto Sans Bold"]
  },
  "paint": {
    "text-color": "#5D4037",
    "text-halo-color": "#FFFFFF",
    "text-halo-width": 1.5
  }
}
```

### Fix 2: Include Streets, Singletrack & Leaf Directories in Extractor

1. **`offline_tile_manager.dart`:**
   - Regional mountain packs: set `maxZoom: 15` (covers all trails, gravel paths, and MTB singletrack).
   - Country master packs: set `maxZoom: 13` (includes town street grids without huge file sizes).
2. **`pmtiles_extractor.dart`:**
   - Implement PMTiles v3 leaf directory serialization so archives with >4,000 tiles write leaf directories and keep the root directory strictly under 16,384 bytes.

### Fix 3: Topographic Contour Layer Integration

1. Create `lib/core/maps/elevation_contour_layer.dart` to manage vector contour PMTiles.
2. Update `OsmTileProviders.getOfflineVectorLayerIfAvailable` to render the contour lines underneath roads and trails but above the earth/forest fill.

---

## 4. Verification Steps

1. **Unit Tests:**
   - `test/theme_inspection_test.dart`: Verify all theme layers (landcover, natural, peaks, contours) parse with zero warnings.
   - `test/pmtiles_extractor_test.dart`: Verify large archive round-trip with leaf directories.
2. **Offline Rendering Verification:**
   - Render offline tiles at zoom 6 (country view), zoom 10 (regional view), and zoom 14 (mountain trail view) to PNG.
   - Verify green forests at country zoom, major road networks, summit icons with elevation labels (`▲ Vf. Omu 2505m`), and 20m/50m/100m contour lines.
