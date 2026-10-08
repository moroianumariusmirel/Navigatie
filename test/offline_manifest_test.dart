import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trailpulse/core/offline/offline_manifest_service.dart';
import 'package:trailpulse/core/offline/offline_download_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineManifest & RegionManifestInfo Serialization', () {
    test('Parses JSON correctly and calculates sizeMb from bytes', () {
      final jsonSample = {
        'version': '2.1.0',
        'updatedAt': '2026-10-08T15:30:00Z',
        'regions': {
          'ro_muntenia_dobrogea': {
            'sizeBytes': 162529280,
            'downloadUrl': 'https://custom-cdn.com/muntenia.pmtiles',
          },
          'ro_all': {
            'sizeMb': 62.5,
            'totalBytes': 65536000,
          },
        },
      };

      final manifest = OfflineManifest.fromJson(jsonSample);
      expect(manifest.version, equals('2.1.0'));
      expect(manifest.updatedAt, isNotNull);
      expect(manifest.regions.length, equals(2));

      final muntenia = manifest.regions['ro_muntenia_dobrogea']!;
      expect(muntenia.regionId, equals('ro_muntenia_dobrogea'));
      expect(muntenia.totalBytes, equals(162529280));
      expect(muntenia.sizeMb, equals(155.0)); // 162529280 / (1024*1024) = 155.0 MB
      expect(muntenia.downloadUrl, equals('https://custom-cdn.com/muntenia.pmtiles'));

      final roAll = manifest.regions['ro_all']!;
      expect(roAll.sizeMb, equals(62.5));
      expect(roAll.totalBytes, equals(65536000));
    });

    test('Bundled fallback manifest contains valid Romanian regions', () {
      final bundled = OfflineManifestService.getBundledDefaultManifest();
      expect(bundled.regions.containsKey('ro_muntenia_dobrogea'), isTrue);
      expect(bundled.regions['ro_muntenia_dobrogea']!.sizeMb, equals(152.0));
    });
  });

  group('OfflineManifestService Remote Fetch & Cache', () {
    test('fetchRemoteManifest successfully parses 200 OK response', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'version': '1.0.0',
            'regions': {
              'ro_bucegi_brasov': {
                'sizeMb': 8.9,
                'totalBytes': 9332326,
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final manifest = await OfflineManifestService.fetchRemoteManifest(
        url: 'https://test-server/manifest.json',
        client: mockClient,
      );

      expect(manifest, isNotNull);
      expect(manifest!.regions['ro_bucegi_brasov']?.sizeMb, equals(8.9));
    });

    test('fetchRemoteManifest gracefully handles 404 or network errors', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final manifest = await OfflineManifestService.fetchRemoteManifest(
        url: 'https://test-server/manifest.json',
        client: mockClient,
      );

      expect(manifest, isNull);
    });
  });

  group('OfflineDownloadService Manifest Application', () {
    test('applyManifest updates in-memory region sizes dynamically', () {
      final service = OfflineDownloadService.test();

      const newManifest = OfflineManifest(
        version: '3.0.0',
        regions: {
          'ro_muntenia_dobrogea': RegionManifestInfo(
            regionId: 'ro_muntenia_dobrogea',
            sizeMb: 165.5,
            totalBytes: 173539328,
          ),
          'ro_transylvania_carpathians': RegionManifestInfo(
            regionId: 'ro_transylvania_carpathians',
            sizeMb: 142.0,
            totalBytes: 148897792,
          ),
        },
      );

      service.applyManifest(newManifest);

      final ro = service.countries.firstWhere((c) => c.id == 'ro');
      final muntenia = ro.regions.firstWhere((r) => r.id == 'ro_muntenia_dobrogea');
      expect(muntenia.sizeMb, equals(165.5));
      expect(muntenia.totalBytes, equals(173539328));

      final transylvania = ro.regions.firstWhere((r) => r.id == 'ro_transylvania_carpathians');
      expect(transylvania.sizeMb, equals(142.0));
      expect(transylvania.totalBytes, equals(148897792));

      // Country total reflects updated region sizes
      expect(ro.effectiveTotalSizeMb, greaterThan(450.0));
    });

    test('syncManifest executes with MockClient and updates service state', () async {
      final service = OfflineDownloadService.test();

      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'version': '2.0.0',
            'regions': {
              'ro_banat_crisana': {
                'sizeMb': 98.4,
                'totalBytes': 103179878,
              },
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final success = await service.syncManifest(
        url: 'https://test.com/manifest.json',
        client: mockClient,
      );

      expect(success, isTrue);
      final ro = service.countries.firstWhere((c) => c.id == 'ro');
      final banat = ro.regions.firstWhere((r) => r.id == 'ro_banat_crisana');
      expect(banat.sizeMb, equals(98.4));
    });
  });
}
