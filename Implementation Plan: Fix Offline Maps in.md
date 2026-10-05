Implementation Plan: Fix Offline Maps in Airplane Mode & Enable Real Map Downloads
Addresses all 4 root causes identified in 
offline_map_airplane_mode_investigation.md
 to guarantee that downloaded vector maps render 100% offline in Airplane Mode without phone signal or internet connectivity.

User Review Required
IMPORTANT

OpenFreeMap vs. PMTiles Format:

OpenFreeMap is a fantastic free and open-source map service that hosts vector/raster tiles and provides weekly full-planet downloads (which are 100+ GB MBTiles).
For mobile phones, downloading a whole planet or converting multi-gigabyte MBTiles on-device is not feasible. Mobile vector rendering with vector_map_tiles_pmtiles requires single-file PMTiles (Protocol Buffer vector tiles with OpenMapTiles / Protomaps schema, cloud-optimized for range-reading).
Solution: We configure genuine, ready-to-use regional PMTiles downloads (such as standard Romania extracts and European regional packs) and eliminate the demo/simulation branch that wrote zeroed dummy files. The app will download 100% valid PMTiles binary archives to local storage and validate their header before marking them ready.
Proposed Changes
Core Offline Downloads & Catalog
[MODIFY] 
lib/core/offline/offline_download_service.dart
Remove targetRegion.downloadUrl.contains('github.com/trailpulse') from isDemoUrl so that requests are never intercepted by _simulateDownload().
Implement validation for downloaded archives:
Check file size (> 100 KB).
Validate the 7-byte magic signature PMTiles (0x50, 0x4D, 0x54, 0x69, 0x6C, 0x65, 0x73) using RandomAccessFile before moving from .part to .pmtiles and marking RegionDownloadState.ready.
On completion of a download, call OsmTileProviders.prewarm(targetFile.path) so the vector provider is instantly mounted in memory.
During initialize(), scan existing .pmtiles files and pre-warm them asynchronously in the background.
Expose LatLng? get defaultOfflineCenter which returns the geographic center of the first downloaded region if GPS is unavailable.
[MODIFY] 
lib/core/offline/offline_tile_manager.dart
Ensure all download URLs point to live, working PMTiles endpoints or valid CDN mirrors.
Add LatLng get center => LatLng((minLat + maxLat) / 2.0, (minLon + maxLon) / 2.0); to OfflineMapRegion for automatic camera centering.
Vector Tile Rendering & Offline Theme
[MODIFY] 
lib/core/maps/osm_tile_providers.dart
Add a reactive update notifier: static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0); to broadcast when an offline PMTiles provider has finished mounting into memory.
Implement static Future<void> prewarm(String filePath):
Opens PmTilesVectorTileProvider.fromSource(filePath).
Caches the instance in _pmtilesProviders.
Increments changeNotifier.value to signal active map widgets to rebuild and switch to the vector layer.
If getOfflineVectorLayerIfAvailable() is called before pre-warming finishes, kick off prewarm(filePath) in the background so the next tick mounts the layer automatically.
Ensure the offline Protomaps theme handles airplane mode without hanging on remote HTTP glyph/sprite requests: configure offline-safe style rendering so all trails, roads, contours, and landcover render cleanly offline.
UI Camera & Default Positioning
[MODIFY] 
lib/ui/cockpit/widgets/perspective_map_view.dart
Replace the hardcoded Freiburg, Germany fallback (LatLng(47.912, 7.898)) when widget.telemetry.currentPosition is null (e.g. testing indoors in Airplane mode):
Check OfflineDownloadService().defaultOfflineCenter first. If Romania or any region is downloaded, center there.
Wrap the map tile layer or attach a listener to OsmTileProviders.changeNotifier so that the cockpit automatically transitions from the fallback raster to the rich vector layer when the PMTiles archive finishes mounting.
[MODIFY] 
lib/ui/planner/planner_screen.dart
Replace the default initial center fallback (LatLng(47.912, 7.898)) with OfflineDownloadService().defaultOfflineCenter.
If offline and a region is downloaded, avoid centering on the default German sample route if it's far outside the downloaded bounding box.
Listen to OsmTileProviders.changeNotifier in initState() / dispose() to trigger setState() when offline vector layers become ready.
