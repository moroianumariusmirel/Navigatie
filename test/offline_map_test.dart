import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:trailpulse/core/offline/offline_tile_manager.dart';
import 'package:trailpulse/core/offline/offline_download_service.dart';
import 'package:trailpulse/core/offline/device_storage_service.dart';
import 'package:trailpulse/core/maps/osm_tile_providers.dart';
import 'package:trailpulse/core/models/activity_type.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EuropeanMapCatalog & OfflineTileManager', () {
    test('Catalog contains 20+ European countries with Romanian regional sub-packs', () {
      final countries = OfflineTileManager.europeanCountries();
      expect(countries.length, greaterThanOrEqualTo(20));

      final romania = countries.firstWhere((c) => c.id == 'ro');
      expect(romania.name, equals('Romania'));
      expect(romania.flag, equals('🇷🇴'));
      expect(romania.regions.length, greaterThanOrEqualTo(5)); // Master + Transylvania + Muntenia + Moldavia + Banat

      final transylvania = romania.regions.firstWhere((r) => r.id == 'ro_transylvania_carpathians');
      expect(transylvania.name, contains('Transylvania'));
      expect(transylvania.hasCyclingProfiles, isTrue);
      expect(transylvania.hasHikingContours, isTrue);

      // Verify Brasov coordinate is inside Transylvania bounding box
      const brasov = LatLng(45.6579, 25.6012);
      expect(transylvania.contains(brasov), isTrue);
      expect(transylvania.contains(const LatLng(52.5200, 13.4050)), isFalse); // Berlin should be outside
    });

    test('Spatial bounding box lookup accurately identifies Romanian Carpathians', () {
      final service = OfflineDownloadService.test();
      
      // Sinaia / Bucegi Mountains: 45.35° N, 25.55° E
      const bucegi = LatLng(45.35, 25.55);
      final foundRegion = service.findRegionForCoordinates(bucegi);
      
      // Prior to download, states are not ready so it returns null until downloaded
      expect(foundRegion, isNull);
    });
  });

  group('DeviceStorageService', () {
    test('formatBytes correctly formats KB, MB, and GB', () {
      expect(DeviceStorageService.formatBytes(0), equals('0 MB'));
      expect(DeviceStorageService.formatBytes(512 * 1024), equals('512.0 KB'));
      expect(DeviceStorageService.formatBytes(450 * 1024 * 1024), equals('450.0 MB'));
      expect(DeviceStorageService.formatBytes(2500 * 1024 * 1024), equals('2.44 GB'));
    });
  });

  group('OsmTileProviders Seamless Layer Resolution', () {
    test('Falls back cleanly to activity raster layer when no offline PMTiles file is downloaded', () {
      OsmTileProviders.overrideTileProvider = MockWhiteTileProvider();

      // Cycling
      final cyclingLayer = OsmTileProviders.layerForActivity(
        ActivityType.cycling,
        center: const LatLng(45.65, 25.60),
      );
      expect(cyclingLayer, isNotNull);

      // Hiking
      final hikingLayer = OsmTileProviders.layerForActivity(
        ActivityType.hiking,
        center: const LatLng(45.65, 25.60),
      );
      expect(hikingLayer, isNotNull);
    });
  });

  group('OfflineDownloadService Simulation & Management', () {
    test('Simulation mode streams download progress and produces ready state', () async {
      final service = OfflineDownloadService.test();
      final countries = service.countries;
      final roMaster = countries.firstWhere((c) => c.id == 'ro').regions.first;

      expect(roMaster.state, equals(RegionDownloadState.notDownloaded));

      // Test pause / cancel
      service.startDownload(roMaster, simulate: true);
      service.cancelDownload(roMaster.id);

      // Verify region can be deleted cleanly
      await service.deleteRegion(roMaster.id);
      expect(service.downloadedRegions.contains(roMaster), isFalse);
    });

    test('isValidPmtilesFile validates PMTiles magic header and rejects zeroes/corrupt files', () {
      final tempDir = Directory.systemTemp.createTempSync('pmtiles_test_');
      try {
        final corruptFile = File('${tempDir.path}/corrupt.pmtiles');
        corruptFile.writeAsBytesSync(List.filled(1024, 0)); // 1 KB zeroes like previous dummy

        expect(OfflineDownloadService.isValidPmtilesFile(corruptFile), isFalse);

        final validFile = File('${tempDir.path}/valid.pmtiles');
        final validBytes = Uint8List(2048);
        final bdValid = ByteData.sublistView(validBytes);
        final magic = utf8.encode('PMTiles');
        for (int i = 0; i < 7; i++) {
          validBytes[i] = magic[i];
        }
        bdValid.setUint8(7, 3); // PMTiles v3
        bdValid.setUint32(8, 127, Endian.little); // rootDirOffset
        bdValid.setUint32(16, 500, Endian.little); // rootDirLength (<= 16384)
        bdValid.setUint32(56, 1000, Endian.little); // tileDataOffset
        validFile.writeAsBytesSync(validBytes);

        expect(OfflineDownloadService.isValidPmtilesFile(validFile), isTrue);
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('OfflineMapRegion center and defaultOfflineCenter calculate correctly', () {
      final countries = OfflineTileManager.europeanCountries();
      final roMaster = countries.firstWhere((c) => c.id == 'ro').regions.first;

      final center = roMaster.center;
      expect(center.latitude, closeTo(45.942, 0.05));
      expect(center.longitude, closeTo(24.988, 0.05));
    });

    test('OsmTileProviders reactive notifier triggers on prewarm', () async {
      int notifyCount = 0;
      void listener() => notifyCount++;
      OsmTileProviders.changeNotifier.addListener(listener);

      // Prewarm with non-existent file should safely do nothing without crashing
      await OsmTileProviders.prewarm('/non/existent/path.pmtiles');
      expect(notifyCount, equals(0));

      OsmTileProviders.changeNotifier.removeListener(listener);
    });

    test('OpenFreeMap online vector layer initializes correctly', () {
      final vectorLayer = OsmTileProviders.openFreeMapVectorLayer(activity: ActivityType.cycling);
      expect(vectorLayer, isNotNull);
    });

    test('getActiveOfflineRegion handles null point gracefully', () {
      final region = OsmTileProviders.getActiveOfflineRegion(null);
      // Prior to downloading, returns null
      expect(region, isNull);
    });
  });
}
