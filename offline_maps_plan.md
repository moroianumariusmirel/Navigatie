# Plan: Offline maps for TrailPulse

## Goal
The app keeps working without phone signal: the map shows, the GPX track and position show, and turn-by-turn voice still works.

---

## 1. What the code does today

| Area | Current state | Works offline? |
|---|---|---|
| Map tiles | All 3 maps ([perspective_map_view.dart:109](file:///home/marius/Documents/APP/Navigatie/lib/ui/cockpit/widgets/perspective_map_view.dart#L109), [planner_screen.dart:408](file:///home/marius/Documents/APP/Navigatie/lib/ui/planner/planner_screen.dart#L408), [interactive_route_map.dart:91](file:///home/marius/Documents/APP/Navigatie/lib/ui/widgets/interactive_route_map.dart#L91)) use `OsmTileProviders.layerForActivity()` ([osm_tile_providers.dart](file:///home/marius/Documents/APP/Navigatie/lib/core/maps/osm_tile_providers.dart)). That uses flutter_map's default `NetworkTileProvider`, which loads tiles live from CyclOSM, OpenTopoMap or OSM. It only keeps tiles in memory, not on disk. | ❌ Blank grey map |
| Offline regions | [offline_tile_manager.dart](file:///home/marius/Documents/APP/Navigatie/lib/core/offline/offline_tile_manager.dart) is **mock data only**: hard-coded regions, a fake "ready" state, and a `localPmtilesPath` field that is never used. | ❌ |
| `ExploreMode.offline` | Only switches the Routes list to the "saved" tab ([planner_screen.dart:236](file:///home/marius/Documents/APP/Navigatie/lib/ui/planner/planner_screen.dart#L236)). It has nothing to do with map tiles. | n/a |
| Saved GPX routes | Stored on disk by `GpxStorageService` | ✅ |
| GPS position | `geolocator` uses satellite GPS, which doesn't need a phone network | ✅ |
| Turn instructions | `TurnNavigationEngine` builds the turns from the GPX coordinates on the phone | ✅ |
| Routing in the planner | `OsmRoutingService` calls `routing.openstreetmap.de`. Without internet it falls back to a spline between your points, which is not a real road route. `OnDeviceOfflineRouter` ([routing_engine.dart](file:///home/marius/Documents/APP/Navigatie/lib/core/routing/routing_engine.dart)) is a stub that just returns a sample route. | ⚠️ Not real routing |
| OSM public traces | `OsmTracesService` calls the OSM API | ❌ (OK, online feature) |
| Voice (TTS) | `flutter_tts` uses the phone's built-in voice engine. On Android the voice may need internet unless an offline voice pack is installed. | ⚠️ Depends on device |
| Fonts | `google_fonts` downloads fonts at runtime by default (the `assets/fonts/` folder exists but may not be used) | ⚠️ Check |

**Main finding:** the map itself is the only critical blocker. The other navigation pieces already work offline.

---

## 2. Tile licence warning (important)

> [!WARNING]
> The tile servers the app uses now (`tile.openstreetmap.org`, OpenTopoMap, CyclOSM, Waymarked Trails) are free community servers. **Their usage policies forbid bulk downloading or prefetching tiles for offline use.** Downloading regions from them could get the app blocked (HTTP 403 / 418) and breaks their terms.
>
> Caching tiles the user has **already looked at** is generally fine. Downloading whole regions needs a source that allows it.

Tile sources that do allow offline use:
- **Protomaps / PMTiles** (recommended): free OSM vector data in single files. You can extract any region with the `pmtiles extract` CLI and host it yourself (S3, Cloudflare R2, any static server). Needs OSM attribution (ODbL).
- **Paid providers with offline terms:** MapTiler, Thunderforest (has OpenCycleMap and Outdoors styles), Stadia. Check each plan's offline/caching clause.
- **Your own tile server** (e.g. rendering OpenTopoMap or CyclOSM styles yourself).

---

## 3. Options compared

| | A. Disk cache only | B. Download along route | C. Offline region packs (PMTiles) |
|---|---|---|---|
| How it works | Every tile shown is saved to disk and reused when there's no signal | When a route is saved, download tiles in a corridor around the track (e.g. 1–2 km, zoom 10–16) | User downloads a region file (100–300 MB) and the map reads tiles from it |
| Effort | Low | Medium | Medium–High |
| Coverage | Only areas already viewed | The planned route | The whole region, including detours |
| Licence | OK with current servers (light caching) | Needs a permissive source | Needs PMTiles or a licensed source |
| Fits existing code | `TileProvider` swap | Hooks into `saveRouteOffline()` | Fills in `OfflineMapRegion.localPmtilesPath` |

**Recommendation: do all three in phases.** A is the safety net, B is the main feature for a GPX-based navigation app, and C is the premium "Offline Regions" screen the UI already pretends to have.

---

## 4. Recommended implementation (phases)

### Phase 1: Cache tiles on disk as they are viewed
1. Add a caching tile provider. Two choices:
   - **`flutter_map_tile_caching` (FMTC):** mature, supports browse caching and region and line downloads, and has its own on-disk database (ObjectBox).
     > [!CAUTION]
     > FMTC is **GPL-3.0** unless you buy a commercial licence. That matters if the app will be closed-source or sold.
   - **Custom `CachedTileProvider`** (no licence issues, about 150 lines): subclass `TileProvider` and return an `ImageProvider` that:
     1. builds the path `<appSupportDir>/tiles/<style>/<z>/<x>/<y>.png` (using `path_provider`, which is already a dependency),
     2. returns the file if it exists (disk first),
     3. otherwise downloads it with `http`, saves it, and returns it,
     4. if there's no network and no file, returns a neutral placeholder tile (`MockWhiteTileProvider` already exists for this).
     Add a size limit (e.g. 500 MB) and delete the least-recently-used tiles when it's exceeded.
2. Wire it into the single choke point: set the `tileProvider` default in `OsmTileProviders` (the `tp ?? ...` lines). All three maps update with no UI changes.
3. Set `fallbackUrl` only when online. Remove or guard it so offline requests don't stall twice.
4. Show a small "OFFLINE – cached map" badge on the cockpit when the network is down (optional `connectivity_plus`).

### Phase 2: Download the route corridor when saving a route
1. New `RouteTilePrefetcher` service in `lib/core/offline/`:
   - Input: `RouteModel.coordinates`, style (cycling or hiking), corridor radius, zoom range.
   - Work out the set of `(z, x, y)` tiles crossed by the track plus the buffer. Use standard slippy-map maths and remove duplicates.
   - Download them with limited concurrency (2–4 at a time), retry on failure, and report progress through a `Stream<double>`.
   - Estimate before downloading: number of tiles × about 20 KB.
2. Trigger it from `TelemetryService.saveRouteOffline()` and from importing a GPX, with an "Download map for offline use (≈ 35 MB)?" prompt.
3. Store per-route metadata (`offlineReady`, tile count, bytes, style) next to the GPX so the Routes list can show an ✅ offline badge.
4. Before navigation: when Start is tapped with no network and no cached corridor, warn the user.
5. **The source must allow bulk download.** Point the prefetcher at a PMTiles, MapTiler or Thunderforest style, not the community servers.

### Phase 3: Real offline region packs (replace the mock `OfflineTileManager`)
1. **Data pipeline (once, on a server or PC):**
   - Download a Protomaps planet build or a Geofabrik extract.
   - Run `pmtiles extract planet.pmtiles black_forest.pmtiles --bbox=...` for each region.
   - Upload the files with a JSON catalog (`id, name, bbox, sizeMb, url, version, sha256`).
2. **App:**
   - `OfflineTileManager` loads the catalog, downloads the `.pmtiles` file to app storage with resume support, checks the sha256, and stores `localPmtilesPath` plus `RegionDownloadState.ready`.
   - Rendering:
     - **Vector:** `vector_map_tiles` + `vector_map_tiles_pmtiles` (a style JSON can go under `assets/styles/`, which is already declared in pubspec). Small files, sharp at every zoom, and styles can be tuned for cycling or hiking.
     - **Raster:** `flutter_map_pmtiles` with raster PMTiles (simpler, bigger files).
   - Pick the tile layer by priority: **downloaded region covering the view → disk cache → network**.
3. UI: an Offline Regions list showing download, progress, delete, update and storage used.
4. Optional: hillshade or contours as a second raster PMTiles overlay for hiking.

### Phase 4: Make the rest of the app fully offline
- **Fonts:** bundle the fonts in `assets/fonts/` and set `GoogleFonts.config.allowRuntimeFetching = false` in `main()`.
- **TTS:** at first launch, or in the audio settings, check whether an offline voice is installed (`flutter_tts.getVoices`, look at `network_required` on Android) and point the user to install it. Chimes already work offline.
- **Planner offline:** keep the current spline fallback but label it "Straight-line (offline)". Real offline routing (BRouter segments, GraphHopper, or Valhalla via FFI as the `OnDeviceOfflineRouter` stub plans) is a separate, larger project. It isn't needed to navigate a pre-planned GPX.
- **Off-route re-routing offline:** keep guiding back to the nearest point on the track (that's what `recalculateOffRoute` does now).

---

## 5. Suggested file and structure changes

```
lib/core/offline/
  cached_tile_provider.dart      # Phase 1 – disk-first TileProvider + LRU
  tile_math.dart                 # lat/lon <-> tile x/y, corridor tile set
  route_tile_prefetcher.dart     # Phase 2 – download tiles along a route
  offline_tile_manager.dart      # Phase 3 – real catalog/download (replace mock)
  offline_region_store.dart      # persist region/route offline metadata
lib/core/maps/osm_tile_providers.dart   # choose region > cache > network
lib/core/telemetry/telemetry_service.dart  # trigger prefetch on save/import, pre-start check
pubspec.yaml                     # e.g. vector_map_tiles(_pmtiles) or flutter_map_pmtiles, connectivity_plus (optional)
```

> [!NOTE]
> The project uses `flutter_map: ^7.0.2`. Check each package's supported flutter_map version before adding it. FMTC and the vector or PMTiles plugins are released in step with specific flutter_map major versions.

---

## 6. Verification plan
1. **Unit tests:** tile maths (known lat/lon → z/x/y), corridor tile count for a sample GPX, and cache hit/miss/LRU eviction using a temp directory (like the existing `permissions_and_storage_test.dart`).
2. **Widget test:** with `overrideTileProvider` pointing at a cache dir with no network, the map renders cached tiles and doesn't throw.
3. **On a device:**
   - Save a GPX route with "download offline" → turn on airplane mode (GPS stays on) → open the cockpit → the map shows along the whole route, the position moves, and voice and chimes play after Start.
   - Pan outside the corridor → placeholder tiles, no crash, and the offline badge shows.
   - Download a region pack → airplane mode → the whole region renders at all zooms.
4. **Storage:** check cache size limits and that "delete region" frees the space.

---

## 7. Order and rough effort
| Phase | Value | Effort |
|---|---|---|
| 1. Disk cache | Fixes "map goes blank when signal drops" for areas already viewed | ~1 day |
| 2. Route corridor download | Full offline navigation of planned GPX routes | 2–3 days (+ choosing a tile source) |
| 3. Region packs (PMTiles) | Offline exploring and planning anywhere | 4–6 days (+ data pipeline) |
| 4. Fonts / TTS / labels | Polish, no hidden network dependencies | ~0.5–1 day |

## Open decisions for you
1. **Tile source for downloads:** self-hosted Protomaps PMTiles (free, more setup) or a paid provider (MapTiler or Thunderforest)?
2. **Licence:** is GPL-3.0 (FMTC) acceptable, or should the cache be custom-built?
3. **Vector or raster** offline maps? Vector gives smaller files and custom cycling/hiking styles; raster keeps today's CyclOSM and OpenTopo look.
