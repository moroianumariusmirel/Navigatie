# TrailPulse Offline Map Loading Diagnostic Report

**Date:** October 8, 2026  
**Status:** Diagnostic Complete (No Code Modified)  
**Target Platform:** Mobile (Android / iOS) — Offline Mode  

---

## Executive Summary

When the TrailPulse app runs on a physical device in **offline mode** (airplane mode or without cellular/Wi-Fi), downloaded vector maps (`.pmtiles`) **fail to load and display**. The map viewport appears as a blank/grey grid or shows nothing.

Following an in-depth audit of the map rendering pipeline, tile providers, state initialization, and navigation viewports, **7 distinct root causes** were identified. The primary blocker is architectural: **the offline map service is never initialized when the app starts up**, causing the entire app to believe zero offline maps have been downloaded. Even when a map has been downloaded, the fallback coordinate system points to Germany (`47.912, 7.898`), causing the app to query for non-downloaded regions and attempt (and fail) to fetch online raster tiles over the internet.

---

## Architecture Flow & Failure Path

```
App Launch (lib/main.dart -> lib/app.dart)
   │
   ├──> OfflineDownloadService.initialize() is NOT called!
   │      └──> _countries remains static with state: RegionDownloadState.notDownloaded
   │
User opens CockpitScreen or PlannerScreen (Offline / Airplane Mode)
   │
   ├──> Telemetry has no GPS lock yet (Indoors or Airplane Mode)
   │      └──> defaultOfflineCenter is queried
   │             └──> Returns null (because all regions are marked notDownloaded)
   │      └──> Fallback coordinate activates: LatLng(47.912, 7.898) [Freiburg, Germany]
   │
Map requests tile layer: OsmTileProviders.layerForActivity(center: userPos)
   │
   ├──> OsmTileProviders.getOfflineVectorLayerIfAvailable(center)
   │      ├──> findRegionForCoordinates(LatLng(47.912, 7.898))
   │      │      └──> Returns null (Germany is not downloaded / all states are notDownloaded)
   │      └──> Returns null!
   │
Fallback to Online Raster Tiles: cyclOsmLayer() / openTopoMapLayer()
   │
   └──> HTTP requests to tile.cyclosm.openstreetmap.fr fail (No internet)
          └──> BLANK / GREY SCREEN
```

---

## Detailed Root Causes

### 1. `OfflineDownloadService.initialize()` Is Never Called at App Startup
* **Location:** [`lib/main.dart`](lib/main.dart#L4-L7), [`lib/app.dart`](lib/app.dart)
* **The Problem:**  
  `main()` only initializes Flutter bindings and launches `TrailPulseApp`:
  ```dart
  void main() {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(const TrailPulseApp());
  }
  ```
  `OfflineDownloadService().initialize()` is **only** called inside `OfflineMapsScreen.initState()` (`lib/ui/offline/offline_maps_screen.dart:31`).
* **Impact:**  
  Unless the user explicitly navigates to the *Settings -> Offline Maps* screen every single time they launch the app:
  1. `_countries` keeps the default initial memory state where every region has `state = RegionDownloadState.notDownloaded`.
  2. `downloadedRegions` returns an empty list `[]`.
  3. `defaultOfflineCenter` returns `null`.
  4. `findRegionForCoordinates()` checks `r.state == RegionDownloadState.ready` and returns `null` for any coordinate.
  5. The app concludes that **no offline maps exist**, bypassing PMTiles completely.

---

### 2. Preference Registry Key Mismatch (`localPmtilesPath` vs `path`)
* **Location:** [`lib/core/offline/offline_download_service.dart:47-51`](lib/core/offline/offline_download_service.dart#L47-L51) vs [`lib/core/offline/offline_tile_manager.dart:103-112`](lib/core/offline/offline_tile_manager.dart#L103-L112)
* **The Problem:**  
  When offline regions are saved to disk, `OfflineDownloadService._persistDownloadedRegistry()` saves `region.toJson()`:
  ```dart
  Map<String, dynamic> toJson() => {
    'id': id,
    'countryId': countryId,
    'state': state.name,
    'localPmtilesPath': localPmtilesPath, // <--- key is 'localPmtilesPath'
    'sizeMb': sizeMb,
    'maxZoom': maxZoom,
  };
  ```
  However, in `OfflineDownloadService.initialize()`:
  ```dart
  for (final item in downloadedRegistry) {
    if (item is Map && item['id'] is String && item['path'] is String) { // <--- looking for 'path'!
      final path = item['path'] as String;
      ...
    }
  }
  ```
* **Impact:**  
  `item['path']` is **always null**. `item['path'] is String` evaluates to `false` for every entry. The entire saved preference registry is discarded on load! The app must rely strictly on scanning the filesystem directory.

---

### 3. Hardcoded Fallback Coordinates Point to Freiburg, Germany (`47.912, 7.898`)
* **Locations:**  
  - [`lib/ui/cockpit/widgets/perspective_map_view.dart:82`](lib/ui/cockpit/widgets/perspective_map_view.dart#L82)
  - [`lib/ui/planner/planner_screen.dart:330-347`](lib/ui/planner/planner_screen.dart#L330-L347)
* **The Problem:**  
  In `PerspectiveMapView`:
  ```dart
  final defaultPos = OfflineDownloadService().defaultOfflineCenter ?? const LatLng(47.912, 7.898);
  final userPos = widget.telemetry.currentPosition ??
      (widget.route?.coordinates.isNotEmpty == true
          ? widget.route!.coordinates.first
          : defaultPos);
  ```
  In `PlannerScreen`:
  ```dart
  final displayRoute = _hasDismissedLoadedRoute
      ? null
      : (_customRoute ??
          fallbackRoute ??
          (defaultOfflineCenter != null
              ? null
              : (isCycling ? RouteModel.sampleSchauinsland() : RouteModel.sampleFeldbergHike())));

  final initialCenter = coordinates.isNotEmpty
      ? coordinates.first
      : (userGps ?? (defaultOfflineCenter ?? const LatLng(47.912, 7.898)));
  ```
* **Impact:**  
  When testing offline or indoors without an active GPS lock:
  1. `defaultOfflineCenter` is `null` (due to Root Causes 1 & 2).
  2. The position defaults to **Freiburg, Germany**.
  3. In `PlannerScreen`, the default route loaded is `sampleSchauinsland()` in Germany.
  4. The map checks if the user has an offline map for Germany. If the user downloaded Romania (`ro_bucegi_brasov` or `ro_all`), Germany is outside the bounds.
  5. The app falls back to online raster tiles (`cyclOsmLayer`), which fail without internet, showing a blank screen.

---

### 4. Static `center` Coordinate Instead of Dynamic Viewport Camera
* **Locations:**  
  - [`lib/ui/cockpit/widgets/perspective_map_view.dart:117`](lib/ui/cockpit/widgets/perspective_map_view.dart#L117)
  - [`lib/ui/planner/planner_screen.dart:416`](lib/ui/planner/planner_screen.dart#L416)
  - [`lib/ui/widgets/interactive_route_map.dart:95`](lib/ui/widgets/interactive_route_map.dart#L95)
* **The Problem:**  
  The tile layer selection is evaluated once using a static initial coordinate:
  ```dart
  ListenableBuilder(
    listenable: OsmTileProviders.changeNotifier,
    builder: (context, _) => OsmTileProviders.layerForActivity(
      widget.activityType,
      center: userPos, // or initialCenter
    ),
  )
  ```
* **Impact:**  
  1. If the user drags or pans the map from their current position into a downloaded offline region, the layer is not rebuilt with the new viewport coordinates.
  2. If the user's initial center was outside the downloaded area (e.g., at home before arriving at the mountain), panning to the mountain region never displays the offline map.
  3. If multiple offline regions are downloaded (e.g. Bucegi and Făgăraș), the system only binds one PMTiles provider based on the single starting center point.

---

### 5. Vector Tile Overzooming Barrier (`maximumTileSubstitutionDifference: 4`)
* **Location:** [`lib/core/maps/osm_tile_providers.dart:127`](lib/core/maps/osm_tile_providers.dart#L127)
* **The Problem:**  
  `VectorTileLayer` specifies:
  ```dart
  maximumTileSubstitutionDifference: 4,
  ```
  The country-wide master region (`ro_all.pmtiles`) has a maximum tile zoom level of **10** (`maxZoom: 10`).
  In `PerspectiveMapView`, the default camera zoom is **14.2**, and can zoom up to **19.0**.
* **Impact:**  
  At zoom levels greater than 14 ($10 + 4 = 14$), `vector_map_tiles` refuses to substitute zoom 10 tiles. If the user is zoomed into street/trail level (zoom 14–18), the tiles disappear, leaving a completely blank map. Setting this to `8` allows smooth overzoomed vector rendering.

---

### 6. Filename ID Matching Vulnerability During Disk Discovery
* **Location:** [`lib/core/offline/offline_download_service.dart:68-69`](lib/core/offline/offline_download_service.dart#L68-L69)
* **The Problem:**  
  When scanning `.pmtiles` files in the offline storage directory:
  ```dart
  final regionId = filename.substring(0, filename.length - 8);
  registeredPaths[regionId] = file.path;
  ```
  The catalog IDs in `OfflineCatalog` use the `ro_` prefix:
  - `ro_all`
  - `ro_bucegi_brasov`
  - `ro_fagaras_sibiu`
* **Impact:**  
  If an archive was named `romania_all.pmtiles` or `romania_bucegi_brasov.pmtiles`, `regionId` evaluates to `romania_all`, which does not match `ro_all`. The catalog lookup `registeredPaths[region.id]` fails to find it, causing the archive to be completely ignored.

---

### 7. Aggressive File Deletion on Prewarming or Validation Hesitation
* **Location:** [`lib/core/offline/offline_download_service.dart:71-74`](lib/core/offline/offline_download_service.dart#L71-L74)
* **The Problem:**  
  If `isValidPmtilesFile(file)` encounters any issue (such as reading 32-bit values instead of 64-bit offsets in the PMTiles v3 header), it executes:
  ```dart
  debugPrint('[OfflineDownloadService] Cleaning up corrupt archive: ${file.path}');
  try {
    file.deleteSync();
  } catch (_) {}
  ```
* **Impact:**  
  If the header check is overly strict or misinterprets header offsets on certain devices or architectures, valid downloaded maps could be deleted from the phone upon app restart.

---

## Action Plan & Recommendations (For Future Implementation)

When ready to apply fixes, here is the exact resolution sequence:

1. **Bootstrap Initialization in `main.dart` / `app.dart`:**
   Call `await OfflineDownloadService().initialize();` inside `main()` after `WidgetsFlutterBinding.ensureInitialized();` so the app always boots with complete offline knowledge.
2. **Correct Serialization Key:**
   In `OfflineDownloadService.initialize()`, read both `item['localPmtilesPath']` and `item['path']`:
   ```dart
   final path = (item['localPmtilesPath'] ?? item['path']) as String?;
   ```
3. **Smart Viewport & Default Location:**
   When telemetry has no GPS lock, prioritize the first downloaded offline region center:
   ```dart
   final defaultPos = OfflineDownloadService().defaultOfflineCenter ?? const LatLng(45.5, 25.5);
   ```
4. **Dynamic Map Center Binding:**
   In `PerspectiveMapView` and `PlannerScreen`, update the tile layer provider on map movement / camera change, or provide a fallback multi-provider tile layer that serves all downloaded offline PMTiles archives simultaneously.
5. **Adjust Vector Tile Substitution Difference:**
   Increase `maximumTileSubstitutionDifference` from `4` to `8` in `VectorTileLayer` so country-level maps (z0–z10) can be cleanly overzoomed up to zoom 18 without disappearing.
6. **Robust Archive Filename Normalization:**
   Support alias matching during disk scanning (e.g. mapping `romania_*` to `ro_*`).
