# Investigation Report: Why Offline Maps Do Not Display in Airplane Mode

**Date:** October 4, 2026  
**Status:** Investigation Complete (Zero Source Code Modified)  
**Report Target:** `offline_map_airplane_mode_investigation.md`

---

## 1. Executive Summary

When testing the newly downloaded Romanian map on a physical phone in **Airplane Mode**, neither the **Cockpit** nor the **Route Planner** displays any map tiles.

Following a code audit across the map rendering pipeline, tile provider subsystem, and download manager, **4 distinct root causes** were identified:

1. **The Download Service wrote a 1 KB dummy file filled with zeroes instead of real PMTiles vector data.**
2. **The Offline Vector Provider loads asynchronously on the first frame, immediately returns `null`, and never triggers a UI rebuild when ready.**
3. **The default fallback coordinates and demo routes are in Freiburg, Germany (`47.912, 7.898`), falling outside Romania's bounding box.**
4. **The default Protomaps vector theme requires online HTTP fonts/glyphs (`protomaps.github.io`).**

---

## 2. Deep Dive Into the Root Causes

---

### Root Cause 1: Dummy File Written Instead of Real PMTiles Archive
* **Location:** [`lib/core/offline/offline_download_service.dart`](file:///home/marius/Documents/APP/Navigatie/lib/core/offline/offline_download_service.dart#L179-L186) and [`lib/core/offline/offline_tile_manager.dart`](file:///home/marius/Documents/APP/Navigatie/lib/core/offline/offline_tile_manager.dart#L12)

#### What happens:
In `offline_tile_manager.dart`:
```dart
static const String cdnBaseUrl =
    'https://github.com/trailpulse/maps/releases/download/v1.0';
```
In `offline_download_service.dart`:
```dart
final isDemoUrl = targetRegion.downloadUrl.contains('example.com') ||
    targetRegion.downloadUrl.contains('github.com/trailpulse') ||
    simulate;

if (isDemoUrl) {
  await _simulateDownload(targetRegion, ...);
}
```
When you pressed "Download" on Romania Master:
- Because the catalog URL contains `github.com/trailpulse`, the app flagged it as a demo/placeholder URL and routed execution into `_simulateDownload()`.
- In `_simulateDownload()`:
  ```dart
  final sink = file.openWrite();
  for (int step = 0; step < 20; step++) {
    ...
    sink.add(List.filled(1024, 0)); // Writes 1024 zeroes
  }
  ```
- The resulting file saved to your phone storage (`ro_all.pmtiles`) is only ~20 KB of binary zeros (`0x00`).
- When the map attempts to mount the archive with `PmTilesArchive.from(filePath)`, the PMTiles parser validates the first 7 bytes for the PMTiles magic signature (`0x50, 0x4D, 0x54, 0x69, 0x6C, 0x65, 0x73` -> "PMTiles").
- Since the file contains only zeros, it throws a `CorruptArchiveException('Invalid magic in header file, found ""')`, fails silently inside `OsmTileProviders`, and no map layer is ever created.

---

### Root Cause 2: Asynchronous Provider Initialization Returning `null` Without Triggering a UI Rebuild
* **Location:** [`lib/core/maps/osm_tile_providers.dart`](file:///home/marius/Documents/APP/Navigatie/lib/core/maps/osm_tile_providers.dart#L76-L89)

#### What happens:
When the Flutter map widget builds its layers:
```dart
var provider = _pmtilesProviders[filePath];
if (provider == null) {
  PmTilesVectorTileProvider.fromSource(filePath).then((p) {
    _pmtilesProviders[filePath] = p;
  }).catchError((e) {
    print('Failed to init PMTiles provider: $e');
  });
  return null; // <--- Returns null immediately!
}
```
1. On the very first frame of the Cockpit or Planner screen, `_pmtilesProviders[filePath]` is not yet in memory.
2. `getOfflineVectorLayerIfAvailable()` returns `null` immediately.
3. In `layerForActivity()`:
   ```dart
   final offlineVector = getOfflineVectorLayerIfAvailable(...);
   if (offlineVector != null) {
     return offlineVector;
   }
   return cyclOsmLayer(tileProvider: tp); // Falls back to online raster layer
   ```
4. Even if the file were valid, when `PmTilesVectorTileProvider.fromSource(filePath)` finishes reading the file asynchronously 100ms later, **it does not notify `PerspectiveMapView` or `PlannerScreen` to call `setState()`**.
5. The map never rebuilds, leaving the map stuck on the online `cyclOsmLayer`. In airplane mode, that online layer cannot reach the internet, resulting in completely blank/gray tiles.

---

### Root Cause 3: Default User Coordinates & Demo Routes Fall Outside Romania's Bounding Box
* **Location:** 
  - [`lib/ui/cockpit/widgets/perspective_map_view.dart`](file:///home/marius/Documents/APP/Navigatie/lib/ui/cockpit/widgets/perspective_map_view.dart#L81-L84)
  - [`lib/ui/planner/planner_screen.dart`](file:///home/marius/Documents/APP/Navigatie/lib/ui/planner/planner_screen.dart#L323-L343)
  - [`lib/core/offline/offline_tile_manager.dart`](file:///home/marius/Documents/APP/Navigatie/lib/core/offline/offline_tile_manager.dart#L44-L49)

#### What happens:
- Romania's geographic boundary defined in the app is:
  ```dart
  minLat: 43.6186, maxLat: 48.2654, minLon: 20.2618, maxLon: 29.7155
  ```
- In **Airplane Mode**, phone GPS location often defaults to `null` initially (or if testing indoors without GPS lock).
- When `currentPos == null`, `PerspectiveMapView` falls back to:
  ```dart
  userPos = const LatLng(47.912, 7.898); // Freiburg / Black Forest, Germany!
  ```
- Similarly, `PlannerScreen` starts by loading a default sample route (`sampleSchauinsland` or `sampleFeldbergHike`), which is also located in Freiburg, Germany (`47.912, 7.898`).
- When `getActiveOfflineRegion(userPos)` checks whether any downloaded map covers that point:
  - Freiburg, Germany is at Longitude `7.898° E`.
  - Romania starts at Longitude `20.2618° E`.
  - The check fails: `findRegionForCoordinates(...)` returns `null`.
- Because the app believes the camera is currently in Germany, it does not activate the Romanian offline map, and instead attempts to fetch German tiles from the online OpenStreetMap servers (which fail in airplane mode).

---

### Root Cause 4: Remote Fonts & Glyphs in Protomaps Themes
* **Location:** [`lib/core/maps/osm_tile_providers.dart`](file:///home/marius/Documents/APP/Navigatie/lib/core/maps/osm_tile_providers.dart#L104-L107)

#### What happens:
`OsmTileProviders` uses the standard Protomaps theme:
```dart
theme: ProtomapsThemes.darkV4() // or lightV4()
```
Inside the `vector_map_tiles_pmtiles` package, `ProtomapsThemes` references online endpoints for typography and icons:
- Glyphs: `'https://protomaps.github.io/basemaps-assets/fonts/{fontstack}/{range}.pbf'`
- Sprites: `'https://protomaps.github.io/basemaps-assets/sprites/v4/dark'`

In Airplane Mode, the vector tile engine cannot fetch font pbfs over HTTP. Without local fallback font stacks, text labels and POI icons fail to render or delay rendering.

---

## 3. Recommended Resolution Plan

To resolve this completely so you can walk outside in airplane mode and have an instant, high-performance offline map:

| Step | Component | Solution |
| :--- | :--- | :--- |
| **1** | **Real Downloads** | Connect the download service to a real, working PMTiles source (e.g. standard Protomaps extracts / OpenFreeMap / Cloudflare R2 / GitHub Release with genuine PMTiles binaries) instead of generating simulated empty files. |
| **2** | **Pre-warm & Rebuild** | Pre-load the `PmTilesVectorTileProvider` when the app starts or immediately upon download completion, and use a `ListenableBuilder` / `ChangeNotifier` so when the provider is ready, the map widget automatically redraws. |
| **3** | **Active Region Fallback** | If GPS has not acquired a lock yet and the user has downloaded offline maps (e.g. Romania), automatically center the default camera on the downloaded region center (e.g. Brasov / Cluj / Bucharest) instead of Germany. |
| **4** | **Local Glyph Assets** | Bundle a local offline glyph/sprite set or configure the vector style renderer to render vector road lines and geometries even when remote font endpoints are unreachable. |

---

## 4. Verification Checklist (Once Approved)
1. Verify the downloaded `.pmtiles` file has valid PMTiles V3 headers (`xxd -l 16 ro_all.pmtiles` shows `PMTiles`).
2. Center map coordinates in Romania (`LatLng(45.6579, 25.6012)`).
3. Enable Airplane Mode.
4. Verify that vector roads, contour lines, hiking paths, and forests render smoothly in both Cockpit and Route Planner.
