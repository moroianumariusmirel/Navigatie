import 'package:flutter_test/flutter_test.dart';
import 'package:trailpulse/core/permissions/permission_service.dart';
import 'package:trailpulse/core/telemetry/telemetry_service.dart';
import 'package:trailpulse/core/models/route_model.dart';

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
}
