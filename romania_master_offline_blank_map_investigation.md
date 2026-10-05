# Investigation: Romania Master Map Shows No Map in Airplane Mode

**Date:** 2026-10-04
**Branch:** `feature/offline-vector-maps-pmtiles`
**Symptom:** After downloading **Romania (Entire Country Master)** with the new in-app extractor and turning on airplane mode, the **Cockpit** and the **Route Planner** show no map. (The small **Bucegi & Brașov** pack and the **Tuscany** pack work.)

---

## 1. TL;DR

The extractor writes a `.pmtiles` file that the reader **can't open**.

[`InAppPmtilesExtractor`](file:///home/marius/Documents/APP/Navigatie/lib/core/offline/pmtiles_extractor.dart) puts **every tile entry into one root directory** and writes **no leaf directories**. The `pmtiles` reader (used by `vector_map_tiles_pmtiles`) only reads the **first 16,384 bytes** of a file, and the header plus the root directory must fit inside them. For Romania Master, the root directory is about **27 KB**, so opening the file throws `CorruptArchiveException('Root directory is out of bounds.')`.

That error is caught and only logged. The app then falls back to the **online** raster layers (CyclOSM / OpenTopoMap), and those can't load in airplane mode, so the map is blank.

---

## 2. Root Cause in Detail

### 2.1 The reader limit (package `pmtiles` 1.3.0)

[`archive.dart` L286-L305](file:///home/marius/.pub-cache/hosted/pub.dev/pmtiles-1.3.0/lib/src/archive.dart#L286-L305):

```dart
static Future<PmTilesArchive> fromReadAt(ReadAt f) async {
  final headerAndRoot =
      await (await f.readAt(0, headerAndRootMaxLength)).toBytes();   // 16384 bytes
  ...
  if (header.rootDirectoryOffset + header.rootDirectoryLength >
      headerAndRoot.length) {
    throw CorruptArchiveException('Root directory is out of bounds.');
  }
```

`headerAndRootMaxLength = 16384` ([header.dart L16](file:///home/marius/.pub-cache/hosted/pub.dev/pmtiles-1.3.0/lib/src/header.dart#L16)). This is also a rule in the PMTiles V3 spec: *"The Root Directory MUST be contained in the first 16,384 bytes"*. Bigger archives must move entries into **leaf directories**.

### 2.2 What the extractor writes

In [`pmtiles_extractor.dart`](file:///home/marius/Documents/APP/Navigatie/lib/core/offline/pmtiles_extractor.dart), `extractRegion()` serializes **all** entries into one directory and hard-codes the leaf section to empty:

```dart
final rootDirBytes = serializeDirectory(extractedEntries);   // ALL tiles
...
bd.setUint32(0x28, 0, Endian.little); // leaf directories offset
bd.setUint32(0x30, 0, Endian.little); // leaf directories length
```

### 2.3 Measured root-directory size per catalog region

I ran the extractor's own `getTileIdsForBounds()` + `serializeDirectory()` against every region in `OfflineTileManager.europeanCountries()`, using realistic tile lengths:

| Region | maxZoom | Tiles | Root dir (gzip) | Opens? |
|---|---|---|---|---|
| **ro_all (Romania Master)** | 12 | 11,322 | **27,243 B** | ❌ too big |
| ro_bucegi_brasov | 15 | 3,688 | 9,040 B | ✅ |
| ro_transylvania_carpathians | 14 | 30,749 | 72,915 B | ❌ |
| ro_muntenia_dobrogea | 14 | 38,950 | 92,527 B | ❌ |
| ro_moldavia_bucovina | 14 | 33,159 | 78,861 B | ❌ |
| ro_banat_crisana | 14 | 32,073 | 76,329 B | ❌ |
| it_tuscany_apennines | (direct file) | 177 | 609 B | ✅ |
| ch_valais_zermatt / ch_bernese_oberland / es_picos_de_europa | 14 | 3.6k–5.5k | 9–13 KB | ✅ |
| **Every other country master and sub-pack** | 14 | 9.8k – 2.3M | 23 KB – 5.4 MB | ❌ |

This explains exactly what you saw: Bucegi and Tuscany work, Romania Master doesn't. **Almost every pack in the catalog has the same problem**, not only Romania.

> The existing unit tests passed because they only check small directories (3 entries) and a small bounding box. None of them opens a large extracted file with `PmTilesArchive`.

---

## 3. Why the Failure Is Silent (Secondary Problems)

These don't cause the blank map, but they hide it from you and make it worse.

### 3.1 The download is marked "ready" even though the file can't be read
[`OfflineDownloadService.isValidPmtilesFile()`](file:///home/marius/Documents/APP/Navigatie/lib/core/offline/offline_download_service.dart#L186-L198) only checks the 7 magic bytes `PMTiles`. The broken file passes, so the UI shows Romania as **downloaded** (with a ~200+ MB size).

### 3.2 The prewarm error is only logged
[`OsmTileProviders.prewarm()` L49-L54](file:///home/marius/Documents/APP/Navigatie/lib/core/maps/osm_tile_providers.dart#L49-L54) catches the `CorruptArchiveException` and calls `debugPrint`. Nothing is stored, so the UI never finds out.

### 3.3 The app retries on every rebuild and falls back to online tiles
[`getOfflineVectorLayerIfAvailable()` L102-L107](file:///home/marius/Documents/APP/Navigatie/lib/core/maps/osm_tile_providers.dart#L102-L107) calls `prewarm()` again each time the widget rebuilds and returns `null`. [`layerForActivity()`](file:///home/marius/Documents/APP/Navigatie/lib/core/maps/osm_tile_providers.dart#L63-L81) then returns `cyclOsmLayer()` / `openTopoMapLayer()`. Those need the internet, so in airplane mode the map is empty. The file is also reopened and fails again on every rebuild.

### 3.4 Broken files stay on disk after the app restarts
On startup, `init()` uses the same magic-only check. Files that were already downloaded broken stay "ready" until someone deletes them by hand.

---

## 4. Solution

### 4.1 (Main fix) Write leaf directories in the extractor

Follow what `go-pmtiles` / `tippecanoe` do:

1. Serialize all entries as a root directory. If `127 + root.length <= 16384`, keep the current single-directory layout.
2. If it's too big, split the sorted entries into chunks of `leafSize` entries (start at 4096). Serialize each chunk as a **leaf directory** and add them one after another into a `leafBytes` buffer.
3. Build the **root** from one entry per leaf: `tileId = first tileId of the chunk`, `runLength = 0` (this marks it as a leaf), `offset` = position inside the leaf section, `length` = compressed leaf length.
4. If that root is still bigger than 16,384 − 127, double `leafSize` and repeat.
5. File layout: `header | root | metadata | leaf directories | tile data`. Set header fields `0x28` (leaf offset = `127 + root + metadata`) and `0x30` (leaf length). Shift `tileDataOffset` to come after the leaves.

Sketch for `pmtiles_extractor.dart`:

```dart
class DirEntry { // generalises ExtractedEntry: runLength 0 = leaf pointer
  final int tileId, offset, length, runLength;
  const DirEntry(this.tileId, this.offset, this.length, this.runLength);
}

static Uint8List serializeEntries(List<DirEntry> e) {
  final b = <int>[];
  writeVarint(b, e.length);
  var last = 0;
  for (final x in e) { writeVarint(b, x.tileId - last); last = x.tileId; }
  for (final x in e) writeVarint(b, x.runLength);
  for (final x in e) writeVarint(b, x.length);
  for (var i = 0; i < e.length; i++) {
    final contiguous = i > 0 && e[i].offset == e[i - 1].offset + e[i - 1].length;
    writeVarint(b, contiguous ? 0 : e[i].offset + 1);
  }
  return Uint8List.fromList(gzip.encode(b));
}

/// Returns (rootBytes, leafBytes).
static (Uint8List, Uint8List) buildDirectories(List<DirEntry> tiles) {
  final single = serializeEntries(tiles);
  if (127 + single.length <= 16384) return (single, Uint8List(0));

  var leafSize = 4096;
  while (true) {
    final leaves = BytesBuilder(copy: false);
    final rootEntries = <DirEntry>[];
    for (var i = 0; i < tiles.length; i += leafSize) {
      final chunk = tiles.sublist(i, min(i + leafSize, tiles.length));
      final leaf = serializeEntries(chunk);
      rootEntries.add(DirEntry(chunk.first.tileId, leaves.length, leaf.length, 0));
      leaves.add(leaf);
    }
    final root = serializeEntries(rootEntries);
    if (127 + root.length <= 16384) return (root, leaves.toBytes());
    leafSize *= 2;
  }
}
```

Then in `buildHeader()`, add `leafDirLength` and write:

```dart
final metaOffset = 127 + rootDirLength;
final leafOffset = metaOffset + metadataLength;
final tileDataOffset = leafOffset + leafDirLength;
bd.setUint32(0x28, leafOffset, Endian.little);
bd.setUint32(0x30, leafDirLength, Endian.little);
bd.setUint32(0x38, tileDataOffset, Endian.little);
```

In `extractRegion()`, write `header`, `root`, `metadata`, `leaves` in that order before streaming tile data. Note that the reader's `Directory.from(..., header:)` checks that leaf entries stay inside `leafDirectoriesLength`, so these header fields must be exact. Also set `0x50` (tile entries) and `0x58` (tile contents) to the real counts (unique contents = `sortedContents.length`).

Rough result: Romania Master needs about 3 leaves of 4096 entries and a root of a few dozen bytes. Norway (2.3M tiles) needs about 570 leaves and a root of about 2 KB. Both fit easily.

### 4.2 Check the file by actually opening it before marking it ready

In `extractRegion()`, after the atomic rename (or on the `.part` file just before it), open the archive and read one tile:

```dart
final check = await PmTilesArchive.fromFile(targetFile);
try {
  final first = await check.tile(firstTileId);
  await first.bytes();             // throws if offsets are wrong
} finally {
  await check.close();
}
```

If this throws, delete the file and report the download as failed. Don't mark it ready.

### 4.3 Make `isValidPmtilesFile` check the header and root

Add a deeper check (async) used by `init()` and `startDownload()`:

- Header magic + `version == 3`.
- `rootDirectoryOffset + rootDirectoryLength <= 16384`.
- `tileDataOffset + tileDataLength <= file.lengthSync()`.

On startup, regions that fail this check go back to `notDownloaded` and their file is deleted. This automatically cleans up the Romania Master file you already downloaded, and the UI asks for a re-download.

### 4.4 Report prewarm failures and stop retrying them

In [`osm_tile_providers.dart`](file:///home/marius/Documents/APP/Navigatie/lib/core/maps/osm_tile_providers.dart):

- Keep a `static final Map<String, Object> _failedPaths`. In the `catch` of `prewarm()`, record the error and bump `changeNotifier`.
- In `getOfflineVectorLayerIfAvailable()`, don't call `prewarm()` again for failed paths.
- Tell `OfflineDownloadService` about it (e.g. `markRegionCorrupt(path)`) so the region shows **"Map file damaged – re-download"** instead of "Ready".

### 4.5 Better behaviour when offline

When there is no usable offline layer, `layerForActivity()` falls back to online raster tiles even with no connection. Two options:

- If any region is downloaded but the current center isn't inside it, use the **nearest downloaded region's** vector layer anyway (it shows what it has).
- Otherwise show a clear "No offline map for this area" overlay instead of an empty gray canvas.

### 4.6 Tests to add

1. **Large-region round-trip:** build a synthetic archive from about 12,000 entries (the Romania Master size) in memory with the new `buildDirectories()` + `buildHeader()`. Open it with `PmTilesArchive.fromBytes()` and check that `lookup()` returns the right offset for the first, middle and last tile IDs.
2. **Catalog guard:** for every region in `europeanCountries()`, check that `127 + root.length <= 16384` after `buildDirectories()`.
3. **Corrupt-file handling:** write a file with a root bigger than 16 KB. Check that `init()` resets the region to `notDownloaded` and that `prewarm()` doesn't loop.

---

## 5. What You Need to Do After the Fix

1. Install the new build.
2. Open the Offline Maps screen. The broken Romania Master download will be cleared automatically (§4.3), or delete it by hand.
3. Download **Romania (Entire Country Master)** again while online.
4. Turn on airplane mode, then open the Cockpit and the Planner. The vector map should render from the local file (zoom 0–12 is stored; higher zoom levels are scaled up from z12, since `PmTilesVectorTileProvider.maximumZoom` reads `archive.maxZoom`).

---

## 6. Summary Table

| # | Problem | Severity | File | Fix |
|---|---|---|---|---|
| 1 | Root directory > 16 KB, no leaf directories → file can't be opened | 🔴 Critical | `pmtiles_extractor.dart` | §4.1 |
| 2 | No real open/read check after extraction | 🟠 High | `pmtiles_extractor.dart` | §4.2 |
| 3 | `isValidPmtilesFile` only checks magic bytes → broken file shows "Ready" | 🟠 High | `offline_download_service.dart` | §4.3 |
| 4 | `prewarm()` failure only logged, retried every rebuild | 🟡 Medium | `osm_tile_providers.dart` | §4.4 |
| 5 | Offline fallback is online raster → blank map | 🟡 Medium | `osm_tile_providers.dart` | §4.5 |
| 6 | Tests only cover small regions | 🟡 Medium | `test/pmtiles_extractor_test.dart` | §4.6 |
