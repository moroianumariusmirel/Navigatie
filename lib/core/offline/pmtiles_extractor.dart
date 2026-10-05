import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pmtiles/pmtiles.dart';
import 'package:pmtiles/src/directory.dart';
import 'offline_tile_manager.dart';

class DirEntry {
  final int tileId;
  final int offset;
  final int length;
  final int runLength;

  const DirEntry({
    required this.tileId,
    required this.offset,
    required this.length,
    this.runLength = 1,
  });
}

typedef ExtractedEntry = DirEntry;

class _TileContent {
  final int sourceOffset;
  final int length;
  final List<int> tileIds = [];
  int destOffset = 0;

  _TileContent({required this.sourceOffset, required this.length});
}

/// On-the-fly PMTiles bounding-box extractor.
/// Streams vector tile data directly from Protomaps daily builds via HTTP Range requests.
class InAppPmtilesExtractor {
  static const String fallbackBuildUrl =
      'https://build.protomaps.com/20261005.pmtiles';
  static const String buildMetadataUrl =
      'https://build-metadata.protomaps.dev/builds.json';

  static int lon2tile(double lon, int z) =>
      ((lon + 180.0) / 360.0 * (1 << z)).floor().clamp(0, (1 << z) - 1);

  static int lat2tile(double lat, int z) {
    final rad = lat * pi / 180.0;
    return ((1.0 - log(tan(rad) + 1.0 / cos(rad)) / pi) / 2.0 * (1 << z))
        .floor()
        .clamp(0, (1 << z) - 1);
  }

  /// Helper to retry transient network failures with exponential backoff
  static Future<T> retry<T>(
    Future<T> Function() action, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    int attempt = 0;
    while (true) {
      try {
        return await action();
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
        await Future.delayed(initialDelay * attempt);
      }
    }
  }

  /// Worker pool to process async tasks with bounded concurrency
  static Future<List<R>> mapConcurrent<T, R>(
    List<T> items,
    Future<R> Function(T item) worker, {
    int concurrency = 6,
    bool Function()? isCancelled,
    void Function(int completedCount, int totalCount)? onProgress,
  }) async {
    if (items.isEmpty) return <R>[];
    final results = List<R?>.filled(items.length, null);
    int nextIndex = 0;
    int completed = 0;

    Future<void> runWorker() async {
      while (true) {
        if (isCancelled != null && isCancelled()) break;
        final i = nextIndex++;
        if (i >= items.length) break;
        results[i] = await worker(items[i]);
        completed++;
        if (onProgress != null && (completed % 50 == 0 || completed == items.length)) {
          onProgress(completed, items.length);
        }
      }
    }

    final workerCount = min(concurrency, items.length);
    final workers = List.generate(workerCount, (_) => runWorker());
    await Future.wait(workers);
    return results.cast<R>();
  }

  /// Discovers the latest daily planet PMTiles build URL.
  static Future<String> getLatestBuildUrl({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final res = await c
          .get(Uri.parse(buildMetadataUrl))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List && data.isNotEmpty) {
          final validBuilds = data.whereType<Map<String, dynamic>>().where((b) {
            final key = b['key'] as String?;
            return key != null && key.endsWith('.pmtiles');
          }).toList();

          if (validBuilds.isNotEmpty) {
            // Sort descending so the latest date string is first (e.g. 20261005 > 20230918)
            validBuilds.sort((a, b) {
              final keyA = a['key'] as String;
              final keyB = b['key'] as String;
              return keyB.compareTo(keyA);
            });
            final newestKey = validBuilds.first['key'] as String;
            debugPrint('[InAppPmtilesExtractor] Selected latest Protomaps build: $newestKey');
            return 'https://build.protomaps.com/$newestKey';
          }
        }
      }
    } catch (e) {
      debugPrint('[InAppPmtilesExtractor] Error discovering build URL ($e), using fallback: $fallbackBuildUrl');
    } finally {
      if (client == null) c.close();
    }
    return fallbackBuildUrl;
  }

  /// Calculates all Hilbert curve tile IDs within the bounding box for [minZoom]..[maxZoom].
  static List<int> getTileIdsForBounds({
    required double minLon,
    required double minLat,
    required double maxLon,
    required double maxLat,
    required int minZoom,
    required int maxZoom,
  }) {
    final tileIds = <int>[];
    for (int z = minZoom; z <= maxZoom; z++) {
      final minX = lon2tile(minLon, z);
      final maxX = lon2tile(maxLon, z);
      final minY = lat2tile(maxLat, z);
      final maxY = lat2tile(minLat, z);
      for (int x = minX; x <= maxX; x++) {
        for (int y = minY; y <= maxY; y++) {
          tileIds.add(ZXY(z, x, y).toTileId());
        }
      }
    }
    tileIds.sort();
    return tileIds;
  }

  /// Writes an unsigned LEB128 varint into [bytes].
  static void writeVarint(List<int> bytes, int value) {
    while (value >= 0x80) {
      bytes.add((value & 0x7F) | 0x80);
      value ~/= 128;
    }
    bytes.add(value & 0x7F);
  }

  /// Serializes directory entries conforming to PMTiles V3 specification.
  static Uint8List serializeEntries(List<DirEntry> entries) {
    final buffer = <int>[];
    writeVarint(buffer, entries.length);
    int lastId = 0;
    for (final e in entries) {
      writeVarint(buffer, e.tileId - lastId);
      lastId = e.tileId;
    }
    for (final e in entries) {
      writeVarint(buffer, e.runLength);
    }
    for (final e in entries) {
      writeVarint(buffer, e.length);
    }
    for (int i = 0; i < entries.length; i++) {
      if (i > 0 &&
          entries[i].offset ==
              entries[i - 1].offset + entries[i - 1].length) {
        writeVarint(buffer, 0);
      } else {
        writeVarint(buffer, entries[i].offset + 1);
      }
    }
    return Uint8List.fromList(gzip.encode(buffer));
  }

  /// Backward-compatible alias
  static Uint8List serializeDirectory(List<DirEntry> entries) =>
      serializeEntries(entries);

  /// Returns (rootBytes, leafBytes).
  /// If single root directory + header fits within 16,384 bytes, returns (rootBytes, empty leafBytes).
  /// Otherwise partitions entries into leaf directory chunks of leafSize, builds leaf directory table
  /// and root directory pointing to the leaves with runLength = 0.
  static (Uint8List, Uint8List) buildDirectories(List<DirEntry> tiles) {
    final single = serializeEntries(tiles);
    if (127 + single.length <= 16384) {
      return (single, Uint8List(0));
    }

    int leafSize = 4096;
    while (true) {
      final leafBuilder = BytesBuilder(copy: false);
      final rootEntries = <DirEntry>[];

      for (int i = 0; i < tiles.length; i += leafSize) {
        final chunk = tiles.sublist(i, min(i + leafSize, tiles.length));
        final leafCompressed = serializeEntries(chunk);
        rootEntries.add(DirEntry(
          tileId: chunk.first.tileId,
          offset: leafBuilder.length,
          length: leafCompressed.length,
          runLength: 0, // Indicates leaf directory in PMTiles v3
        ));
        leafBuilder.add(leafCompressed);
      }

      final root = serializeEntries(rootEntries);
      if (127 + root.length <= 16384 || leafSize >= tiles.length) {
        return (root, leafBuilder.toBytes());
      }
      leafSize *= 2;
    }
  }

  /// Builds a 127-byte PMTiles V3 header.
  static Uint8List buildHeader({
    required int rootDirLength,
    required int metadataLength,
    int leafDirLength = 0,
    required int tileDataLength,
    required int tileCount,
    int? uniqueContentsCount,
    required int minZoom,
    required int maxZoom,
    required double minLon,
    required double minLat,
    required double maxLon,
    required double maxLat,
    required int centerZoom,
    required double centerLon,
    required double centerLat,
  }) {
    final bytes = Uint8List(127);
    final bd = ByteData.sublistView(bytes);

    final magic = utf8.encode('PMTiles');
    for (int i = 0; i < 7; i++) {
      bytes[i] = magic[i];
    }
    bd.setUint8(0x07, 3); // PMTiles v3
    bd.setUint32(0x08, 127, Endian.little); // root directory offset
    bd.setUint32(0x10, rootDirLength, Endian.little);
    final metaOffset = 127 + rootDirLength;
    bd.setUint32(0x18, metaOffset, Endian.little);
    bd.setUint32(0x20, metadataLength, Endian.little);
    final leafOffset = metaOffset + metadataLength;
    bd.setUint32(0x28, leafOffset, Endian.little); // leaf directories offset
    bd.setUint32(0x30, leafDirLength, Endian.little); // leaf directories length
    final tileDataOffset = leafOffset + leafDirLength;
    bd.setUint32(0x38, tileDataOffset, Endian.little);
    bd.setUint32(0x40, tileDataLength & 0xFFFFFFFF, Endian.little);
    bd.setUint32(0x44, (tileDataLength >> 32) & 0xFFFFFFFF, Endian.little);
    bd.setUint32(0x48, tileCount & 0xFFFFFFFF, Endian.little);
    bd.setUint32(0x50, tileCount & 0xFFFFFFFF, Endian.little);
    bd.setUint32(0x58, (uniqueContentsCount ?? tileCount) & 0xFFFFFFFF, Endian.little);
    bd.setUint8(0x60, 1); // clustered
    bd.setUint8(0x61, 2); // gzip internal compression
    bd.setUint8(0x62, 2); // gzip tile compression
    bd.setUint8(0x63, 1); // mvt vector tiles
    bd.setUint8(0x64, minZoom);
    bd.setUint8(0x65, maxZoom);
    bd.setInt32(0x66, (minLon * 10000000).round(), Endian.little);
    bd.setInt32(0x6A, (minLat * 10000000).round(), Endian.little);
    bd.setInt32(0x6E, (maxLon * 10000000).round(), Endian.little);
    bd.setInt32(0x72, (maxLat * 10000000).round(), Endian.little);
    bd.setUint8(0x76, centerZoom);
    bd.setInt32(0x77, (centerLon * 10000000).round(), Endian.little);
    bd.setInt32(0x7B, (centerLat * 10000000).round(), Endian.little);

    return bytes;
  }

  /// Extracts a region bounding box directly into [targetFile] with zero temp files left on error.
  static Future<void> extractRegion({
    required OfflineMapRegion region,
    required File targetFile,
    required void Function(double progress, int receivedBytes, int totalBytes)
        onProgress,
    required bool Function() isCancelled,
    http.Client? httpClient,
  }) async {
    final tempFile = File('${targetFile.path}.part');
    if (tempFile.existsSync()) tempFile.deleteSync();

    final client = httpClient ?? http.Client();
    PmTilesArchive? remoteArchive;
    IOSink? sink;

    try {
      if (isCancelled()) throw Exception('Extraction cancelled');
      onProgress(0.01, 0, (region.sizeMb * 1024 * 1024).round());

      final remoteUrl = await getLatestBuildUrl(client: client);
      if (isCancelled()) throw Exception('Extraction cancelled');

      debugPrint('[InAppPmtilesExtractor] Opening remote archive: $remoteUrl');
      remoteArchive = await PmTilesArchive.fromUri(Uri.parse(remoteUrl), client: client);

      const minZoom = 0;
      final maxZoom = region.maxZoom;

      debugPrint(
          '[InAppPmtilesExtractor] Calculating tile IDs for ${region.id} [${region.minLon}, ${region.minLat}, ${region.maxLon}, ${region.maxLat}], maxZoom $maxZoom');

      final tileIds = getTileIdsForBounds(
        minLon: region.minLon,
        minLat: region.minLat,
        maxLon: region.maxLon,
        maxLat: region.maxLat,
        minZoom: minZoom,
        maxZoom: maxZoom,
      );

      if (isCancelled()) throw Exception('Extraction cancelled');
      debugPrint('[InAppPmtilesExtractor] Total candidate tiles: ${tileIds.length}');

      // Phase 1: Lookup tile locations in remote archive with bounded concurrency and retry
      final contentsByOffset = <int, _TileContent>{};
      final tileToContent = <int, _TileContent>{};

      final entries = await mapConcurrent<int, Entry?>(
        tileIds,
        (id) => retry(() => remoteArchive!.lookup(id)),
        concurrency: 6,
        isCancelled: isCancelled,
        onProgress: (completed, total) {
          final lookupProgress = 0.01 + (completed / total) * 0.09;
          onProgress(lookupProgress, 0, (region.sizeMb * 1024 * 1024).round());
        },
      );

      for (int j = 0; j < tileIds.length; j++) {
        final entry = entries[j];
        final id = tileIds[j];
        if (entry != null && !entry.isLeaf && entry.length > 0) {
          final content = contentsByOffset.putIfAbsent(
            entry.offset,
            () => _TileContent(sourceOffset: entry.offset, length: entry.length),
          );
          content.tileIds.add(id);
          tileToContent[id] = content;
        }
      }

      if (tileToContent.isEmpty) {
        throw Exception('No vector tiles found for bounding box in remote archive');
      }

      // Phase 2: Compute destination layout & directory
      final sortedContents = contentsByOffset.values.toList()
        ..sort((a, b) => a.sourceOffset.compareTo(b.sourceOffset));

      int destOffset = 0;
      for (final c in sortedContents) {
        c.destOffset = destOffset;
        destOffset += c.length;
      }
      final totalTileDataLength = destOffset;

      final extractedEntries = <ExtractedEntry>[];
      tileToContent.forEach((id, content) {
        extractedEntries.add(ExtractedEntry(
          tileId: id,
          offset: content.destOffset,
          length: content.length,
          runLength: 1,
        ));
      });
      extractedEntries.sort((a, b) => a.tileId.compareTo(b.tileId));

      final (rootDirBytes, leafDirBytes) = buildDirectories(extractedEntries);

      // Metadata JSON
      final metadataMap = {
        'name': region.name,
        'description': region.description,
        'minzoom': minZoom,
        'maxzoom': maxZoom,
        'bounds': '${region.minLon},${region.minLat},${region.maxLon},${region.maxLat}',
        'format': 'pbf',
        'type': 'baselayer',
      };
      final metadataBytes =
          Uint8List.fromList(gzip.encode(utf8.encode(json.encode(metadataMap))));

      // 127-byte header
      final headerBytes = buildHeader(
        rootDirLength: rootDirBytes.length,
        metadataLength: metadataBytes.length,
        leafDirLength: leafDirBytes.length,
        tileDataLength: totalTileDataLength,
        tileCount: extractedEntries.length,
        uniqueContentsCount: sortedContents.length,
        minZoom: minZoom,
        maxZoom: maxZoom,
        minLon: region.minLon,
        minLat: region.minLat,
        maxLon: region.maxLon,
        maxLat: region.maxLat,
        centerZoom: region.maxZoom >= 10 ? 10 : region.maxZoom,
        centerLon: (region.minLon + region.maxLon) / 2.0,
        centerLat: (region.minLat + region.maxLat) / 2.0,
      );

      // Open stream to .part file
      sink = tempFile.openWrite();
      sink.add(headerBytes);
      sink.add(rootDirBytes);
      sink.add(metadataBytes);
      if (leafDirBytes.isNotEmpty) {
        sink.add(leafDirBytes);
      }

      // Phase 3: Coalesce adjacent tile contents into batched HTTP Range requests
      final chunks = <List<_TileContent>>[];
      List<_TileContent> currentChunk = [];
      int currentRangeStart = -1;
      int currentRangeEnd = -1;

      for (final c in sortedContents) {
        if (currentChunk.isEmpty) {
          currentChunk.add(c);
          currentRangeStart = c.sourceOffset;
          currentRangeEnd = c.sourceOffset + c.length;
        } else {
          final gap = c.sourceOffset - currentRangeEnd;
          if (gap <= 2048 &&
              (c.sourceOffset + c.length - currentRangeStart) < 2 * 1024 * 1024) {
            currentChunk.add(c);
            currentRangeEnd = c.sourceOffset + c.length;
          } else {
            chunks.add(currentChunk);
            currentChunk = [c];
            currentRangeStart = c.sourceOffset;
            currentRangeEnd = c.sourceOffset + c.length;
          }
        }
      }
      if (currentChunk.isNotEmpty) {
        chunks.add(currentChunk);
      }

      debugPrint(
          '[InAppPmtilesExtractor] Downloading $totalTileDataLength bytes in ${chunks.length} range requests (leaves: ${leafDirBytes.length} bytes)...');

      final sourceTileDataOffset = remoteArchive.header.tileDataOffset;
      int receivedBytes = 0;

      for (int i = 0; i < chunks.length; i++) {
        if (isCancelled()) throw Exception('Extraction cancelled');

        final chunk = chunks[i];
        final start = chunk.first.sourceOffset;
        final end = chunk.last.sourceOffset + chunk.last.length;
        final rangeHeader =
            'bytes=${sourceTileDataOffset + start}-${sourceTileDataOffset + end - 1}';

        final bodyBytes = await retry(() async {
          final req = http.Request('GET', Uri.parse(remoteUrl));
          req.headers['Range'] = rangeHeader;
          final res = await client.send(req);

          if (res.statusCode != 206 && res.statusCode != 200) {
            throw Exception('HTTP ${res.statusCode} fetching range $rangeHeader');
          }

          return await res.stream.toBytes();
        });

        for (final c in chunk) {
          final s = c.sourceOffset - start;
          final e = s + c.length;
          sink.add(bodyBytes.sublist(s, e));
          receivedBytes += c.length;
        }

        final progress = 0.10 + (receivedBytes / totalTileDataLength) * 0.90;
        onProgress(progress.clamp(0.0, 1.0), receivedBytes, totalTileDataLength);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (isCancelled()) throw Exception('Extraction cancelled');

      // Verify extracted archive integrity by reading back a tile before marking complete
      final checkArchive = await PmTilesArchive.fromFile(tempFile);
      try {
        final firstTile = await checkArchive.tile(extractedEntries.first.tileId);
        final tileBytes = firstTile.bytes();
        if (tileBytes.isEmpty) {
          throw Exception('Extracted tile verification failed: byte stream is empty');
        }
      } finally {
        await checkArchive.close();
      }

      if (isCancelled()) throw Exception('Extraction cancelled');

      // Atomic rename
      if (targetFile.existsSync()) targetFile.deleteSync();
      await tempFile.rename(targetFile.path);

      debugPrint(
          '[InAppPmtilesExtractor] Successfully extracted ${targetFile.path} (${targetFile.lengthSync()} bytes)');
    } catch (e) {
      if (sink != null) {
        await sink.close();
      }
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
      rethrow;
    } finally {
      if (remoteArchive != null) {
        await remoteArchive.close();
      }
      if (httpClient == null) {
        client.close();
      }
    }
  }
}
