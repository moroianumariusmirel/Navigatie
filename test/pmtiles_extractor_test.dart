import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pmtiles/pmtiles.dart';
import 'package:pmtiles/src/directory.dart';
import 'package:trailpulse/core/offline/pmtiles_extractor.dart';
import 'package:trailpulse/core/offline/offline_tile_manager.dart';
import 'package:trailpulse/core/offline/offline_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InAppPmtilesExtractor Unit Tests', () {
    test('lon2tile and lat2tile produce valid slippy map coordinates', () {
      // Prime Meridian / Equator
      expect(InAppPmtilesExtractor.lon2tile(0, 0), equals(0));
      expect(InAppPmtilesExtractor.lat2tile(0, 0), equals(0));

      // Zoom 1
      expect(InAppPmtilesExtractor.lon2tile(10.0, 1), equals(1));
      expect(InAppPmtilesExtractor.lon2tile(-10.0, 1), equals(0));

      // Brasov / Romania coordinates at zoom 10
      final x = InAppPmtilesExtractor.lon2tile(25.6, 10);
      final y = InAppPmtilesExtractor.lat2tile(45.6, 10);
      expect(x, greaterThan(0));
      expect(y, greaterThan(0));
    });

    test('getTileIdsForBounds generates sorted Hilbert tile IDs for Bucegi', () {
      final tileIds = InAppPmtilesExtractor.getTileIdsForBounds(
        minLon: 25.4,
        minLat: 45.4,
        maxLon: 25.8,
        maxLat: 45.8,
        minZoom: 0,
        maxZoom: 6,
      );

      expect(tileIds, isNotEmpty);
      // Verify tileIds are strictly sorted
      for (int i = 0; i < tileIds.length - 1; i++) {
        expect(tileIds[i], lessThanOrEqualTo(tileIds[i + 1]));
      }
      // Tile 0 (world tile at z0) must be present
      expect(tileIds.contains(0), isTrue);
    });

    test('writeVarint correctly encodes LEB128 unsigned integers', () {
      final bytes = <int>[];
      InAppPmtilesExtractor.writeVarint(bytes, 0);
      expect(bytes, equals([0]));

      bytes.clear();
      InAppPmtilesExtractor.writeVarint(bytes, 127);
      expect(bytes, equals([127]));

      bytes.clear();
      InAppPmtilesExtractor.writeVarint(bytes, 128);
      expect(bytes, equals([0x80, 0x01]));

      bytes.clear();
      InAppPmtilesExtractor.writeVarint(bytes, 300);
      expect(bytes, equals([0xAC, 0x02]));
    });

    test('serializeDirectory produces valid PMTiles V3 directory readable by Directory.from', () {
      final entries = [
        const DirEntry(tileId: 10, offset: 0, length: 500),
        const DirEntry(tileId: 15, offset: 500, length: 600),
        const DirEntry(tileId: 20, offset: 1100, length: 700),
      ];

      final compressed = InAppPmtilesExtractor.serializeDirectory(entries);
      expect(compressed, isNotEmpty);

      final uncompressed = io.gzip.decode(compressed);
      final dir = Directory.from(uncompressed);

      expect(dir.entries.length, equals(3));
      expect(dir.entries[0].tileId, equals(10));
      expect(dir.entries[0].offset, equals(0));
      expect(dir.entries[0].length, equals(500));

      expect(dir.entries[1].tileId, equals(15));
      expect(dir.entries[1].offset, equals(500));
      expect(dir.entries[1].length, equals(600));

      expect(dir.entries[2].tileId, equals(20));
      expect(dir.entries[2].offset, equals(1100));
      expect(dir.entries[2].length, equals(700));
    });

    test('buildHeader creates a valid 127-byte PMTiles V3 header', () {
      final headerBytes = InAppPmtilesExtractor.buildHeader(
        rootDirLength: 256,
        metadataLength: 128,
        leafDirLength: 0,
        tileDataLength: 50000,
        tileCount: 25,
        minZoom: 0,
        maxZoom: 14,
        minLon: 25.4,
        minLat: 45.4,
        maxLon: 25.8,
        maxLat: 45.8,
        centerZoom: 10,
        centerLon: 25.6,
        centerLat: 45.6,
      );

      expect(headerBytes.length, equals(127));

      final header = Header(ByteData.sublistView(headerBytes));
      header.validate();

      expect(utf8.decode(header.magic), equals('PMTiles'));
      expect(header.version, equals(3));
      expect(header.rootDirectoryOffset, equals(127));
      expect(header.rootDirectoryLength, equals(256));
      expect(header.metadataOffset, equals(127 + 256));
      expect(header.metadataLength, equals(128));
      expect(header.leafDirectoriesLength, equals(0));
      expect(header.tileDataOffset, equals(127 + 256 + 128));
      expect(header.tileDataLength, equals(50000));
      expect(header.minZoom, equals(0));
      expect(header.maxZoom, equals(14));
      expect(header.minPosition.latitude, closeTo(45.4, 0.001));
      expect(header.minPosition.longitude, closeTo(25.4, 0.001));
      expect(header.maxPosition.latitude, closeTo(45.8, 0.001));
      expect(header.maxPosition.longitude, closeTo(25.8, 0.001));
    });

    test('buildDirectories generates leaf directories for large regions (>12,000 entries) and satisfies 16KB root limit', () async {
      final rnd = Random(42);
      final entries = <DirEntry>[];
      int currentOffset = 0;
      for (int i = 0; i < 15000; i++) {
        final len = 2000 + rnd.nextInt(50000);
        entries.add(DirEntry(
          tileId: i * 3 + rnd.nextInt(2),
          offset: currentOffset,
          length: len,
          runLength: 1,
        ));
        currentOffset += len;
      }

      final single = InAppPmtilesExtractor.serializeEntries(entries);
      expect(single.length, greaterThan(16384), reason: 'Single directory must exceed 16KB');

      final (rootDir, leafDir) = InAppPmtilesExtractor.buildDirectories(entries);

      // Root directory MUST fit in first 16,384 bytes (including 127 byte header)
      expect(127 + rootDir.length, lessThanOrEqualTo(16384));
      expect(leafDir, isNotEmpty);

      // Verify that PmTilesArchive can open and resolve entries from this leaf structure
      final metadataBytes = Uint8List.fromList(io.gzip.encode(utf8.encode('{}')));
      final headerBytes = InAppPmtilesExtractor.buildHeader(
        rootDirLength: rootDir.length,
        metadataLength: metadataBytes.length,
        leafDirLength: leafDir.length,
        tileDataLength: currentOffset,
        tileCount: entries.length,
        uniqueContentsCount: entries.length,
        minZoom: 0,
        maxZoom: 12,
        minLon: 20.0,
        minLat: 43.0,
        maxLon: 30.0,
        maxLat: 48.0,
        centerZoom: 10,
        centerLon: 25.0,
        centerLat: 45.0,
      );

      final builder = BytesBuilder(copy: false);
      builder.add(headerBytes);
      builder.add(rootDir);
      builder.add(metadataBytes);
      builder.add(leafDir);
      builder.add(Uint8List(currentOffset)); // synthetic tile data payload

      final archive = await PmTilesArchive.fromBytes(builder.toBytes());
      expect(archive.version, equals(3));
      expect(archive.root.entries.length, greaterThan(0));

      // Test lookups across leaf boundaries
      for (final idx in [0, 4095, 4096, 8192, 14999]) {
        final expected = entries[idx];
        final found = await archive.lookup(expected.tileId);
        expect(found, isNotNull);
        expect(found!.offset, equals(expected.offset));
        expect(found.length, equals(expected.length));
      }
    });

    test('isValidPmtilesFile enforces strict PMTiles V3 rootDirectoryOffset + length <= 16384', () {
      final tempDir = io.Directory.systemTemp.createTempSync('pmtiles_val_test_');
      try {
        // 1. Create file with oversized root directory (> 16384)
        final oversizedFile = io.File('${tempDir.path}/oversized.pmtiles');
        final bytes = Uint8List(20000);
        final bd = ByteData.sublistView(bytes);
        final magic = utf8.encode('PMTiles');
        for (int i = 0; i < 7; i++) {
          bytes[i] = magic[i];
        }
        bd.setUint8(7, 3);
        bd.setUint32(8, 127, Endian.little);
        bd.setUint32(16, 25000, Endian.little); // 25KB root dir -> exceeds 16384!
        bd.setUint32(56, 127 + 25000, Endian.little); // tileDataOffset
        oversizedFile.writeAsBytesSync(bytes);

        expect(OfflineDownloadService.isValidPmtilesFile(oversizedFile), isFalse);

        // 2. Create valid PMTiles file with root <= 16384
        final validFile = io.File('${tempDir.path}/valid.pmtiles');
        final validBytes = Uint8List(5000);
        final bdValid = ByteData.sublistView(validBytes);
        for (int i = 0; i < 7; i++) {
          validBytes[i] = magic[i];
        }
        bdValid.setUint8(7, 3);
        bdValid.setUint32(8, 127, Endian.little);
        bdValid.setUint32(16, 1000, Endian.little); // 1KB root dir
        bdValid.setUint32(56, 127 + 1000, Endian.little); // tileDataOffset
        validFile.writeAsBytesSync(validBytes);

        expect(OfflineDownloadService.isValidPmtilesFile(validFile), isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Romanian catalog includes Bucegi Mountains & Brasov with maxZoom 15', () {
      final countries = OfflineTileManager.europeanCountries();
      final ro = countries.firstWhere((c) => c.id == 'ro');
      final bucegi = ro.regions.firstWhere((r) => r.id == 'ro_bucegi_brasov');

      expect(bucegi.name, contains('Bucegi'));
      expect(bucegi.maxZoom, equals(15));
      expect(bucegi.sizeMb, closeTo(11.5, 1.0));
      expect(bucegi.minLat, equals(45.3));
      expect(bucegi.maxLat, equals(45.75));
    });
  });
}
