import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionStatus {
  final bool isLocationGranted;
  final bool isStorageGranted;
  final bool isLocationPermanentlyDenied;
  final bool isStoragePermanentlyDenied;

  const AppPermissionStatus({
    required this.isLocationGranted,
    required this.isStorageGranted,
    this.isLocationPermanentlyDenied = false,
    this.isStoragePermanentlyDenied = false,
  });

  bool get areAllGranted => isLocationGranted && isStorageGranted;

  factory AppPermissionStatus.allGranted() {
    return const AppPermissionStatus(
      isLocationGranted: true,
      isStorageGranted: true,
      isLocationPermanentlyDenied: false,
      isStoragePermanentlyDenied: false,
    );
  }
}

class PermissionService {
  /// Prompts the Android OS for initial Location and Storage permissions on app launch
  static Future<AppPermissionStatus> requestInitialAppPermissions() async {
    if (kIsWeb) {
      // Flutter Web permissions are handled by browser prompts at request time
      return AppPermissionStatus.allGranted();
    }

    try {
      // 1. Request GPS / Location permission (Fine + Coarse)
      final locationStatus = await Permission.locationWhenInUse.request();

      // 2. Request Storage permission (Read/Write external storage for GPX files)
      final storageStatus = await Permission.storage.request();

      return AppPermissionStatus(
        isLocationGranted: locationStatus.isGranted || locationStatus.isLimited,
        isStorageGranted: storageStatus.isGranted || storageStatus.isLimited,
        isLocationPermanentlyDenied: locationStatus.isPermanentlyDenied,
        isStoragePermanentlyDenied: storageStatus.isPermanentlyDenied,
      );
    } catch (e) {
      debugPrint('[PermissionService] Error requesting permissions: $e');
      return const AppPermissionStatus(
        isLocationGranted: false,
        isStorageGranted: false,
      );
    }
  }

  /// Checks the current status of Location and Storage permissions without prompting
  static Future<AppPermissionStatus> checkPermissionStatus() async {
    if (kIsWeb) {
      return AppPermissionStatus.allGranted();
    }

    try {
      final locationStatus = await Permission.locationWhenInUse.status;
      final storageStatus = await Permission.storage.status;

      return AppPermissionStatus(
        isLocationGranted: locationStatus.isGranted || locationStatus.isLimited,
        isStorageGranted: storageStatus.isGranted || storageStatus.isLimited,
        isLocationPermanentlyDenied: locationStatus.isPermanentlyDenied,
        isStoragePermanentlyDenied: storageStatus.isPermanentlyDenied,
      );
    } catch (e) {
      debugPrint('[PermissionService] Error checking permissions: $e');
      return const AppPermissionStatus(
        isLocationGranted: false,
        isStorageGranted: false,
      );
    }
  }

  /// Opens the device settings page for the app if permissions were permanently denied
  static Future<bool> openSettings() async {
    if (kIsWeb) return false;
    return await openAppSettings();
  }

  /// Requests notification permission (Android 13+ / iOS) for foreground download indicators
  static Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.notification.request();
      return status.isGranted || status.isLimited;
    } catch (e) {
      debugPrint('[PermissionService] Error requesting notification permission: $e');
      return false;
    }
  }

  /// Checks if notification permission is currently granted
  static Future<bool> isNotificationGranted() async {
    if (kIsWeb) return true;
    try {
      final status = await Permission.notification.status;
      return status.isGranted || status.isLimited;
    } catch (_) {
      return false;
    }
  }
}
