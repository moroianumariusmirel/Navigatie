import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:trailpulse/core/permissions/permission_service.dart';
import 'package:trailpulse/core/telemetry/telemetry_service.dart';
import 'package:trailpulse/core/models/route_model.dart';
import 'package:trailpulse/core/models/activity_type.dart';
import 'package:trailpulse/core/navigation/audio_navigation_service.dart';
import 'package:trailpulse/core/storage/app_preferences_io.dart';
import 'package:trailpulse/core/storage/gpx_storage_io.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PermissionService Unit Tests', () {
    test('AppPermissionStatus correctly identifies granted vs denied states', () {
      const allGranted = AppPermissionStatus(isLocationGranted: true, isStorageGranted: true);
      expect(allGranted.areAllGranted, isTrue);

      const locationOnly = AppPermissionStatus(isLocationGranted: true, isStorageGranted: false);
      expect(locationOnly.areAllGranted, isFalse);

      const noneGranted = AppPermissionStatus(isLocationGranted: false, isStorageGranted: false);
      expect(noneGranted.areAllGranted, isFalse);

      final factoryGranted = AppPermissionStatus.allGranted();
      expect(factoryGranted.areAllGranted, isTrue);
    });

    test('TelemetryService accurately updates and exposes permission status', () {
      final telemetry = TelemetryService(autoStartSimulation: false);
      expect(telemetry.permissionStatus.isLocationGranted, isFalse);
      expect(telemetry.permissionStatus.isStorageGranted, isFalse);

      telemetry.updatePermissionStatus(const AppPermissionStatus(
        isLocationGranted: true,
        isStorageGranted: true,
      ));

      expect(telemetry.permissionStatus.isLocationGranted, isTrue);
      expect(telemetry.permissionStatus.isStorageGranted, isTrue);
      expect(telemetry.permissionStatus.areAllGranted, isTrue);
    });
  });

  group('GpxStorageService Unit Tests', () {
    test('saveRouteOffline adds route and invokes disk persistence safely', () async {
      final telemetry = TelemetryService(autoStartSimulation: false);
      final initialCount = telemetry.savedOfflineRoutes.length;

      const testRoute = RouteModel(
        id: 'test-custom-route-999',
        name: 'Custom Peak Trail',
        totalDistanceKm: 12.5,
        totalAscentM: 450,
        totalDescentM: 450,
        maxElevationM: 1200,
        minElevationM: 750,
        estimatedDuration: '1h 15m',
        difficultyRating: 'Moderate',
        surfaceBreakdown: {'Gravel': 100},
        elevationProfile: [],
        maneuvers: [],
        coordinates: [],
      );

      telemetry.saveRouteOffline(testRoute);
      expect(telemetry.savedOfflineRoutes.length, equals(initialCount + 1));
      expect(telemetry.savedOfflineRoutes.any((r) => r.id == 'test-custom-route-999'), isTrue);

      // Remove route
      telemetry.removeOfflineRoute('test-custom-route-999');
      expect(telemetry.savedOfflineRoutes.length, equals(initialCount));
    });
  });

  group('Cockpit & Routes Persistence Unit Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('trailpulse_test_');
      AppPreferencesPlatformStorage.testDirectory = tempDir;
      GpxPlatformStorage.testDirectory = tempDir;
    });

    tearDown(() async {
      await AppPreferencesPlatformStorage.flush();
      AppPreferencesPlatformStorage.testDirectory = null;
      GpxPlatformStorage.testDirectory = null;
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('Cockpit tile order, enabled status, audio mode, and activity type persist across app restarts', () async {
      final telemetry1 = TelemetryService(autoStartSimulation: false);
      // Wait for any initial async preference load
      await telemetry1.loadPersistentState();

      // Customize cockpit tiles
      telemetry1.reorderBentoTiles(0, 3);
      telemetry1.setTileEnabled(BentoTileType.heartRate, false);
      telemetry1.setAudioMode(NavigationAudioMode.chimesOnly);
      telemetry1.setActivityType(ActivityType.hiking);
      await telemetry1.savePreferences();

      // Verify custom state in first instance
      expect(telemetry1.bentoTileOrder.contains(BentoTileType.heartRate), isFalse);
      expect(telemetry1.audioMode, equals(NavigationAudioMode.chimesOnly));
      expect(telemetry1.activityType, equals(ActivityType.hiking));

      final savedOrder = List<BentoTileType>.from(telemetry1.bentoTileOrder);

      // Simulate app restart with a brand new TelemetryService instance
      final telemetry2 = TelemetryService(autoStartSimulation: false);
      await telemetry2.loadPersistentState();

      // Verify restored cockpit customizations match exactly
      expect(telemetry2.bentoTileOrder, equals(savedOrder));
      expect(telemetry2.bentoTileOrder.contains(BentoTileType.heartRate), isFalse);
      expect(telemetry2.audioMode, equals(NavigationAudioMode.chimesOnly));
      expect(telemetry2.activityType, equals(ActivityType.hiking));
    });

    test('Deleted routes remain deleted and never reappear after restart', () async {
      final telemetry1 = TelemetryService(autoStartSimulation: false);
      await telemetry1.loadPersistentState();

      final schauinslandId = RouteModel.sampleSchauinsland().id;
      expect(telemetry1.savedOfflineRoutes.any((r) => r.id == schauinslandId), isTrue);

      // User deletes the route
      await telemetry1.removeOfflineRoute(schauinslandId);
      expect(telemetry1.savedOfflineRoutes.any((r) => r.id == schauinslandId), isFalse);
      expect(telemetry1.deletedRouteIds.contains(schauinslandId), isTrue);

      // Simulate app restart
      final telemetry2 = TelemetryService(autoStartSimulation: false);
      await telemetry2.loadPersistentState();
      await telemetry2.loadSavedRoutesFromDisk();

      // Deleted route MUST NOT reappear
      expect(telemetry2.savedOfflineRoutes.any((r) => r.id == schauinslandId), isFalse);
      expect(telemetry2.deletedRouteIds.contains(schauinslandId), isTrue);
    });

    test('Re-importing or saving a deleted route removes it from deletedRouteIds', () async {
      final telemetry = TelemetryService(autoStartSimulation: false);
      await telemetry.loadPersistentState();

      const customRoute = RouteModel(
        id: 'user_created_trail_42',
        name: 'Alpine Crest',
        totalDistanceKm: 18.0,
        totalAscentM: 600,
        totalDescentM: 600,
        maxElevationM: 1400,
        minElevationM: 800,
        estimatedDuration: '2h',
        difficultyRating: 'Hard',
        surfaceBreakdown: {'Rock': 100},
        elevationProfile: [],
        maneuvers: [],
        coordinates: [],
      );

      // Save, then delete
      await telemetry.saveRouteOffline(customRoute);
      expect(telemetry.savedOfflineRoutes.any((r) => r.id == customRoute.id), isTrue);

      await telemetry.removeOfflineRoute(customRoute.id);
      expect(telemetry.savedOfflineRoutes.any((r) => r.id == customRoute.id), isFalse);
      expect(telemetry.deletedRouteIds.contains(customRoute.id), isTrue);

      // Re-save (user imports or creates it again)
      await telemetry.saveRouteOffline(customRoute);
      expect(telemetry.savedOfflineRoutes.any((r) => r.id == customRoute.id), isTrue);
      expect(telemetry.deletedRouteIds.contains(customRoute.id), isFalse);
    });
  });
}
