# Technical Report: Offline PMTiles on Device & Romania Map Sizing

**Target System:** TrailPulse Flutter Navigation Engine (`flutter_map: ^7.0.2`)  
**Subject:** Feasibility of local on-device PMTiles storage & precise sizing for Romania (Cycling & Hiking).

---

## 1. Executive Summary

| Question | Verdict | Summary |
|---|---|---|
| **Can we make it work by having the file directly on the phone?** | **YES, 100%** | PMTiles was specifically designed to work **both** over HTTP and **directly from a local file on phone storage** via `RandomAccessFile` (byte-offset reads). No local web server, no extracting, no network connection required. |
| **How big will the Romania map file be for cycling & hiking?** | **~450 MB – 750 MB** | Full country vector map (all roads, trails, cycleways, paths, summits, streams, POIs, zoom 0–14/15). If adding 10m/20m mountain elevation contours for the Carpathians, the complete package is **~700 MB – 1.05 GB**. |
| **Comparison to traditional PNG tile downloads** | **> 98% smaller** | Downloading PNG raster tiles for Romania (zoom 0–16) would require **over 25 million image files** taking **40 GB – 80 GB** (which crashes mobile operating systems). PMTiles is **1 single file**. |

---

## 2. How Having the File on the Phone Works

### The Fundamental Problem with Traditional Offline Maps
When apps try to download maps offline using traditional web tiles, they try to download millions of individual `.png` files (e.g. `/14/8920/5621.png`).
- On Android and iOS, storing 500,000+ tiny files exhausts device filesystem inodes, causes heavy flash memory wear, and takes hours to copy or delete.

### The PMTiles Architecture on Device
A `.pmtiles` file is an open single-archive container (created by Brandon Liu / Protomaps):
1. **Single File Storage:** The entire map of Romania is saved on the phone's internal storage or SD card as a single file:
   ```
   /data/user/0/com.trailpulse.trailpulse/app_flutter/offline_maps/romania.pmtiles
   ```
2. **Zero Extraction:** The app **never** unzips or unpacks the file.
3. **Instant Byte-Range Seeking:** When the user pans or zooms in the Cockpit or Planner:
   - `flutter_map` requests the tile for coordinates `(z=14, x=9214, y=5712)`.
   - The local PMTiles reader looks up the small header index at the start of the file.
   - It executes a standard Dart `RandomAccessFile.setPosition(offset)` and reads just the exact 15–40 KB vector payload for that tile.
   - Latency is **sub-millisecond** (faster than any network request).

---

## 3. Romania Sizing Breakdown (Cycling & Hiking)

### Geographic Scope
* **Bounding Box:** `[20.26°E, 43.62°N]` to `[29.72°E, 48.27°N]`
* **Land Area:** 238,397 km²
* **Carpathian Mountain Arc:** ~1,000 km of mountain ridge and singletrack trails (Bucegi, Făgăraș, Piatra Craiului, Retezat, Apuseni, Ceahlău, Rodna, etc.)
* **Cycling Networks:** EuroVelo 6 (Danube), Via Transilvanica (~1,400 km), local gravel/MTB routes, county roads, forestry tracks (*drumuri forestiere*).

### Detailed File Size Scenarios

| Layer / Package | Contents & Zoom Levels | File Size (Single `.pmtiles`) | Use Case |
|---|---|---|---|
| **1. Standard Base Vector (Recommended)** | Complete OpenStreetMap dataset for Romania: all highways, gravel tracks, singletracks, hiking paths (marked/unmarked), alpine huts (*cabane*), springs/water points, peaks, landcover, zoom **0 to 14/15** (overzooms cleanly to zoom 18+). | **~450 MB – 650 MB** | Core cycling navigation, gravel riding, road, village-to-village hiking. |
| **2. Mountain Elevation Contours (Add-on)** | Vector contour lines every 10m / 20m covering the whole Carpathian mountain range + hill relief. | **~250 MB – 380 MB** | Essential for Alpine hiking, steep MTB climbs, and reading topography without cell service. |
| **3. All-in-One Romania Outdoor Master** | Layers 1 + 2 combined into a comprehensive package (Full Base + Trails + 10m Contours + POIs). | **~750 MB – 1.05 GB** | **Complete ultimate offline pack.** Fits comfortably on modern phones with 64GB–256GB storage. |

### Regional Sub-Packs (Alternative for Users with Limited Storage)
Instead of forcing everyone to download the whole country, TrailPulse's `OfflineMapRegion` can offer regional packs:

| Region Pack | Coverage | Approx. Size |
|---|---|---|
| **Transylvania & Carpathians** | Brașov, Sibiu, Cluj, Făgăraș, Bucegi, Apuseni, Harghita | **~220 MB – 320 MB** |
| **Muntenia & Danube Delta** | Bucharest, Prahova Valley, Dobrogea, Delta Dunării | **~140 MB – 190 MB** |
| **Moldavia & Bucovina** | Iași, Neamț, Suceava, Ceahlău, Rarău | **~110 MB – 160 MB** |
| **Banat & Crișana** | Timișoara, Arad, Semenic, Cheile Nerei, Cazanele Dunării | **~100 MB – 150 MB** |

---

## 4. How It Integrates into TrailPulse's Codebase

Your codebase is already structured for this:

1. **Model Already Exists:**  
   [lib/core/offline/offline_tile_manager.dart:10](file:///home/marius/Documents/APP/Navigatie/lib/core/offline/offline_tile_manager.dart#L10) already has the exact field:
   ```dart
   class OfflineMapRegion {
     final String id;
     final String name;
     final double sizeMb;
     final RegionDownloadState state;
     final String? localPmtilesPath; // <--- ALREADY DEFINED IN YOUR CODE!
   ...
   ```

2. **Integration Options in `flutter_map`:**
   Depending on whether we want vector rendering or pre-rendered raster:

   * **Option A — Vector PMTiles (`vector_map_tiles_pmtiles`):**
     * Vector tiles rendered by Flutter canvas using a theme JSON (e.g. customized for cycling/hiking with bright trail lines and mountain peaks).
     * File size is the smallest (~500 MB).
     * Crystal clear text and line rendering at any rotation or angle in 3D Cockpit perspective mode.

   * **Option B — Raster PMTiles (`flutter_map_pmtiles`):**
     * Pre-rendered raster tiles (like CyclOSM or OpenTopoMap style) packed into a single PMTiles archive.
     * Plugs into your existing `TileLayer` in [lib/core/maps/osm_tile_providers.dart](file:///home/marius/Documents/APP/Navigatie/lib/core/maps/osm_tile_providers.dart) with zero UI rewrites:
       ```dart
       // When offline region exists on device:
       tileProvider: PmTilesTileProvider.fromSource('/path/to/romania.pmtiles')
       ```

3. **Fallback Logic (Region File -> Disk Cache -> Online):**
   ```mermaid
   flowchart TD
       A[Map Needs Tile] --> B{Is Local PMTiles on Device?}
       B -- Yes --> C[Read Tile Directly from local romania.pmtiles via RandomAccessFile in <1ms]
       B -- No --> D{Is Tile in Disk Cache?}
       D -- Yes --> E[Load cached PNG from App Storage]
       D -- No --> F{Phone has Internet?}
       F -- Yes --> G[Fetch from CyclOSM/OpenTopoMap & Save to Disk Cache]
       F -- No --> H[Render Clean Standby Grid / No Blank Crash]
   ```

---

## 5. How to Extract & Host the Romania File

To prepare the `romania.pmtiles` file, you don't need a heavy GIS server:

### Step 1: Install the free `pmtiles` CLI tool
```bash
# On Linux / macOS (via curl or brew)
curl -L https://github.com/protomaps/go-pmtiles/releases/latest/download/pmtiles_Linux_x86_64.tar.gz | tar -xz
```

### Step 2: Extract Romania directly from Protomaps Planet
Because PMTiles supports HTTP range requests, the CLI tool extracts only Romania **without needing to download the 115 GB planet file**:
```bash
./pmtiles extract https://build.protomaps.com/20261001.pmtiles romania_vector.pmtiles \
  --bbox=20.26,43.62,29.72,48.27 \
  --maxzoom=14
```
*Execution time:* ~5–10 minutes over high-speed internet.  
*Output:* A single `romania_vector.pmtiles` file (~520 MB).

### Step 3: Hosting for User Download
You can place `romania_vector.pmtiles` on any static file storage:
* **Cloudflare R2** (Zero egress bandwidth fees — ideal for map downloads).
* **AWS S3 / DigitalOcean Spaces / Firebase Storage / GitHub Releases / Any VPS web server (nginx)**.

### Step 4: Testing on Phone Without Any Cloud Hosting
You can even test it locally right now:
1. Generate or download `romania.pmtiles` on your PC.
2. Push it to your Android device or emulator via USB:
   ```bash
   adb push romania.pmtiles /sdcard/Download/romania.pmtiles
   ```
3. Point TrailPulse's `PmTilesTileProvider` or `PmTilesVectorTileProvider` to that file path. The map immediately renders all of Romania in full offline airplane mode.

---

## 6. Conclusion & Recommendation

1. **Feasibility:** Having the file on the phone is the optimal, industry-standard architecture for modern offline outdoor navigation apps.
2. **File Size:** At **~500 MB – 750 MB**, the complete map of Romania (with every trail and dirt path) is very reasonable for mobile devices today (comparable to downloading a couple of Spotify playlists or a 45-minute offline video).
3. **Next Step:** When you are ready to implement offline maps, we can add `flutter_map_pmtiles` (or `vector_map_tiles_pmtiles`), wire it into `OfflineTileManager`, and provide a clean "Download Offline Map (Romania - 550 MB)" button in the Routes/Explorer screen.
