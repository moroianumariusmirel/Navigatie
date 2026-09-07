import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide Path;

class RouteProjectionResult {
  final LatLng closestPoint;
  final double distanceOffRouteMeters;
  final double distanceTraveledKm;
  final double distanceRemainingKm;
  final double progressRatio;
  final int closestSegmentIndex;

  const RouteProjectionResult({
    required this.closestPoint,
    required this.distanceOffRouteMeters,
    required this.distanceTraveledKm,
    required this.distanceRemainingKm,
    required this.progressRatio,
    required this.closestSegmentIndex,
  });
}

class LocationService {
  static const Distance _distance = Distance();

  /// Check if device location services (GPS) are toggled ON
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('[LocationService] Error checking location service: $e');
      return false;
    }
  }

  /// Check whether the app has location permission
  static Future<bool> hasPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('[LocationService] Error checking permission: $e');
      return false;
    }
  }

  /// Request location permission from the OS
  static Future<bool> requestPermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
    } catch (e) {
      debugPrint('[LocationService] Error requesting permission: $e');
      return false;
    }
  }

  /// Fetch single current GPS position with high accuracy
  static Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location service is disabled on device');
        return null;
      }

      final permGranted = await hasPermission();
      if (!permGranted) {
        final requested = await requestPermission();
        if (!requested) return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
    } catch (e) {
      debugPrint('[LocationService] Error acquiring current position: $e');
      // Fallback: try last known position if fresh fix timed out
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Listen to continuous live GPS updates from hardware
  static Stream<Position> getPositionStream({
    int distanceFilterMeters = 2,
  }) {
    late LocationSettings settings;

    if (defaultTargetPlatform == TargetPlatform.android) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
        forceLocationManager: false,
        intervalDuration: const Duration(seconds: 1),
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: distanceFilterMeters,
        pauseLocationUpdatesAutomatically: false,
      );
    } else {
      settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters,
      );
    }

    return Geolocator.getPositionStream(locationSettings: settings);
  }

  /// Projects user's real GPS position onto the route polyline,
  /// computing distance traveled along route and distance remaining to destination.
  static RouteProjectionResult projectOntoRoute(
    LatLng userPos,
    List<LatLng> routeCoordinates,
  ) {
    if (routeCoordinates.isEmpty) {
      return RouteProjectionResult(
        closestPoint: userPos,
        distanceOffRouteMeters: 0,
        distanceTraveledKm: 0,
        distanceRemainingKm: 0,
        progressRatio: 0,
        closestSegmentIndex: 0,
      );
    }

    if (routeCoordinates.length == 1) {
      final offRoute = _distance(userPos, routeCoordinates.first);
      return RouteProjectionResult(
        closestPoint: routeCoordinates.first,
        distanceOffRouteMeters: offRoute,
        distanceTraveledKm: 0,
        distanceRemainingKm: 0,
        progressRatio: 1.0,
        closestSegmentIndex: 0,
      );
    }

    // 1. Calculate cumulative segment distances
    final cumulativeDistancesM = <double>[0.0];
    for (int i = 0; i < routeCoordinates.length - 1; i++) {
      final segDist = _distance(routeCoordinates[i], routeCoordinates[i + 1]);
      cumulativeDistancesM.add(cumulativeDistancesM.last + segDist);
    }
    final totalRouteDistM = cumulativeDistancesM.last;

    // 2. Find nearest segment and closest projection point
    double minDistanceToPolyline = double.infinity;
    LatLng bestProjectedPoint = routeCoordinates.first;
    int bestSegmentIndex = 0;
    double bestAlongSegmentM = 0.0;

    for (int i = 0; i < routeCoordinates.length - 1; i++) {
      final p1 = routeCoordinates[i];
      final p2 = routeCoordinates[i + 1];

      final (projected, distOff, distAlong) = _projectPointOnSegment(userPos, p1, p2);
      if (distOff < minDistanceToPolyline) {
        minDistanceToPolyline = distOff;
        bestProjectedPoint = projected;
        bestSegmentIndex = i;
        bestAlongSegmentM = distAlong;
      }
    }

    // 3. Compute traveled and remaining distances along route
    final traveledM = cumulativeDistancesM[bestSegmentIndex] + bestAlongSegmentM;
    final remainingM = math.max(0.0, totalRouteDistM - traveledM);
    final ratio = totalRouteDistM > 0 ? (traveledM / totalRouteDistM).clamp(0.0, 1.0) : 0.0;

    return RouteProjectionResult(
      closestPoint: bestProjectedPoint,
      distanceOffRouteMeters: minDistanceToPolyline,
      distanceTraveledKm: traveledM / 1000.0,
      distanceRemainingKm: remainingM / 1000.0,
      progressRatio: ratio,
      closestSegmentIndex: bestSegmentIndex,
    );
  }

  /// Calculates perpendicular projection of a point onto a line segment (p1 -> p2)
  static (LatLng, double, double) _projectPointOnSegment(LatLng p, LatLng p1, LatLng p2) {
    final segLengthM = _distance(p1, p2);
    if (segLengthM == 0) {
      return (p1, _distance(p, p1), 0.0);
    }

    // Work in local planar projection approximation for speed & accuracy over short segments
    final dx = p2.longitude - p1.longitude;
    final dy = p2.latitude - p1.latitude;
    final lengthSq = dx * dx + dy * dy;

    if (lengthSq == 0) {
      return (p1, _distance(p, p1), 0.0);
    }

    // Projection factor t
    final t = (((p.longitude - p1.longitude) * dx + (p.latitude - p1.latitude) * dy) / lengthSq).clamp(0.0, 1.0);

    final projLat = p1.latitude + t * dy;
    final projLon = p1.longitude + t * dx;
    final projected = LatLng(projLat, projLon);

    final distOff = _distance(p, projected);
    final distAlong = segLengthM * t;

    return (projected, distOff, distAlong);
  }
}
