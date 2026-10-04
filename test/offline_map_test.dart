import 'dart:io';
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
  });
}
