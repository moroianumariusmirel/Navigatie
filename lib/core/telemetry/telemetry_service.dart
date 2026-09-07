import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../models/telemetry_data.dart';
import '../models/route_model.dart';
import '../models/elevation_point.dart';
import '../models/activity_type.dart';
import '../permissions/permission_service.dart';
import '../storage/gpx_storage_service.dart';

class TelemetryService extends ChangeNotifier {
  TelemetryData _currentData = const TelemetryData();
  RouteModel? _activeRoute;
  ActivityType _activityType = ActivityType.cycling;
  Timer? _simulationTimer;
  bool _isRecording = true;
  double _simStep = 0;

  TelemetryService({RouteModel? initialRoute, bool autoStartSimulation = true}) {
    _activeRoute = initialRoute ?? RouteModel.sampleSchauinsland();
    _activityType = _activeRoute!.activityType;
    _initTelemetryFromRoute(_activeRoute!, initialDistanceKm: 24.1);
    if (autoStartSimulation) {
      startSimulation();
    }
  }

  int _selectedTabIndex = 2; // Default to Cockpit (Index 2)
  int get selectedTabIndex => _selectedTabIndex;

  void setSelectedTabIndex(int index) {
    if (_selectedTabIndex != index) {
      _selectedTabIndex = index;
      notifyListeners();
    }
  }

  final List<RouteModel> _savedOfflineRoutes = [
    RouteModel.sampleSchauinsland(),
    RouteModel.sampleFeldbergHike(),
  ];

  AppPermissionStatus _permissionStatus = const AppPermissionStatus(
    isLocationGranted: false,
    isStorageGranted: false,
  );

  TelemetryData get currentData => _currentData;
  RouteModel? get activeRoute => _activeRoute;
  ActivityType get activityType => _activityType;
  bool get isRecording => _isRecording;
  List<RouteModel> get savedOfflineRoutes => List.unmodifiable(_savedOfflineRoutes);
  AppPermissionStatus get permissionStatus => _permissionStatus;

  void updatePermissionStatus(AppPermissionStatus status) {
    _permissionStatus = status;
    notifyListeners();
  }

  /// Loads saved GPX files from device storage into the offline routes library
  Future<void> loadSavedRoutesFromDisk() async {
    final loaded = await GpxStorageService.loadAllSavedGpxRoutes();
    bool addedAny = false;
    for (final route in loaded) {
      if (!_savedOfflineRoutes.any((r) => r.id == route.id)) {
        _savedOfflineRoutes.add(route);
        addedAny = true;
      }
    }
    if (addedAny) {
      notifyListeners();
    }
  }

  void saveRouteOffline(RouteModel route) {
    if (!_savedOfflineRoutes.any((r) => r.id == route.id)) {
      _savedOfflineRoutes.add(route);
      GpxStorageService.saveGpxToFile(route);
      notifyListeners();
    }
  }

  void removeOfflineRoute(String routeId) {
    _savedOfflineRoutes.removeWhere((r) => r.id == routeId);
    GpxStorageService.deleteGpxFile(routeId);
    notifyListeners();
  }

  void setActivityType(ActivityType type) {
    if (_activityType == type && _activeRoute != null) return;
    _activityType = type;
    if (type == ActivityType.cycling) {
      _activeRoute = RouteModel.sampleSchauinsland();
      _initTelemetryFromRoute(_activeRoute!, initialDistanceKm: 24.1);
    } else {
      _activeRoute = RouteModel.sampleFeldbergHike();
      _initTelemetryFromRoute(_activeRoute!, initialDistanceKm: 8.2);
    }
    notifyListeners();
  }

  void updateActiveRoute(RouteModel newRoute) {
    _activeRoute = newRoute;
    _activityType = newRoute.activityType;
    _simStep = 0;
    _initTelemetryFromRoute(newRoute, initialDistanceKm: 0.0);
    notifyListeners();
  }

  void toggleRecording() {
    _isRecording = !_isRecording;
    notifyListeners();
  }

  void _initTelemetryFromRoute(RouteModel route, {double initialDistanceKm = 0.0}) {
    final distTraveled = initialDistanceKm.clamp(0.0, route.totalDistanceKm);
    final distLeft = math.max(0.0, route.totalDistanceKm - distTraveled);
    final progress = route.totalDistanceKm > 0 ? (distTraveled / route.totalDistanceKm) : 0.0;

    final (apex, maxGrade) = _extractApexAndMaxGrade(route);
    final (curEle, curGrade) = interpolateElevationAndGrade(route.elevationProfile, distTraveled);
    final ascentLeft = computeRemainingAscent(route.elevationProfile, distTraveled, curEle);
    final (gpsPos, heading) = _interpolateGpsPosition(
      route.coordinates,
      progress,
      _currentData.currentHeadingDegrees,
    );

    final isCycling = _activityType == ActivityType.cycling;
    final initialSpeed = isCycling ? 34.2 : 4.6;
    final initialAvgSpeed = isCycling ? 23.8 : 3.8;
    final initialMaxSpeed = isCycling ? 58.4 : 7.2;
    final vam = _calculateVam(initialSpeed, curGrade);
    final eta = _formatEta(distLeft, initialSpeed, _activityType);

    _currentData = _currentData.copyWith(
      currentSpeedKmH: initialSpeed,
      avgSpeedKmH: initialAvgSpeed,
      maxSpeedKmH: initialMaxSpeed,
      currentElevationM: double.parse(curEle.toStringAsFixed(1)),
      currentGradePercent: double.parse(curGrade.toStringAsFixed(1)),
      vamAscentRateMh: vam,
      apexElevationM: apex,
      maxGradePercent: double.parse(maxGrade.toStringAsFixed(1)),
      ascentRemainingM: double.parse(ascentLeft.toStringAsFixed(0)),
      totalDistanceKm: route.totalDistanceKm,
      distanceTraveledKm: double.parse(distTraveled.toStringAsFixed(2)),
      distanceRemainingKm: double.parse(distLeft.toStringAsFixed(1)),
      etaFormatted: eta,
      currentLatitude: gpsPos.latitude,
      currentLongitude: gpsPos.longitude,
      currentHeadingDegrees: heading,
      heartRateBpm: isCycling ? 176 : 152,
      heartRateZone: isCycling ? 'Z5 PEAK' : 'Z3 TEMPO',
      isHeartRatePeakAlert: isCycling,
      cadenceRpm: isCycling ? 88 : 112,
      powerWatts: isCycling ? 310 : 145,
      powerFtpPercent: isCycling ? 112 : 95,
      wattsPerKg: isCycling ? 4.2 : 2.1,
    );
  }

  /// High-fidelity telemetry simulator (5Hz - 200ms) to animate HUD & 3D Cockpit
  void startSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!_isRecording || _activeRoute == null) return;
      _simStep += 0.05;

      final isCycling = _activityType == ActivityType.cycling;
      final profile = _activeRoute!.elevationProfile;
      final coords = _activeRoute!.coordinates;
      final totalDist = _activeRoute!.totalDistanceKm;

      // 1. Current slope estimation for physics response
      final currentDistance = _currentData.distanceTraveledKm;
      final (currentElevation, currentGrade) = interpolateElevationAndGrade(profile, currentDistance);

      // 2. Realistic dynamics oscillations based on activity & slope pitch
      final baseSpeed = isCycling ? 28.0 : 4.4;
      final gradeSpeedFactor = isCycling
          ? (1.0 - (currentGrade / 24.0)).clamp(0.35, 1.8)
          : (1.0 - (currentGrade / 30.0)).clamp(0.5, 1.4);

      final speedWobble = math.sin(_simStep) * (isCycling ? 1.5 : 0.25) +
          (math.Random().nextDouble() - 0.5) * 0.15;
      final currentSpeed = ((baseSpeed * gradeSpeedFactor) + speedWobble).clamp(
        isCycling ? 8.0 : 1.5,
        isCycling ? 65.0 : 7.8,
      );

      // 3. Distance & Elevation progression along route
      double nextDistanceTraveled = currentDistance + (currentSpeed / 3600.0) * 0.2;
      if (totalDist > 0 && nextDistanceTraveled >= totalDist) {
        nextDistanceTraveled = 0.0; // Loop seamlessly for continuous HUD preview
      }
      final distanceLeft = math.max(0.0, totalDist - nextDistanceTraveled);
      final progress = totalDist > 0 ? (nextDistanceTraveled / totalDist).clamp(0.0, 1.0) : 0.0;

      // 4. Update elevation, slope, remaining ascent at new distance
      final (nextEle, nextGrade) = interpolateElevationAndGrade(profile, nextDistanceTraveled);
      final remainingAscent = computeRemainingAscent(profile, nextDistanceTraveled, nextEle);
      final (apex, maxGrade) = _extractApexAndMaxGrade(_activeRoute!);
      final vam = _calculateVam(currentSpeed, nextGrade);
      final (gpsPos, heading) = _interpolateGpsPosition(coords, progress, _currentData.currentHeadingDegrees);
      final eta = _formatEta(distanceLeft, currentSpeed, _activityType);

      // 5. Bio-mechanical exertion responsive to slope incline
      final effortFactor = (1.0 + (nextGrade / 14.0)).clamp(0.7, 1.65);

      final hrBase = isCycling ? 152 : 138;
      final hr = ((hrBase * effortFactor) + (math.sin(_simStep * 0.8) * 3)).round().clamp(100, 195);
      final isPeakHr = hr >= (isCycling ? 174 : 165);
      final hrZone = hr >= (isCycling ? 174 : 165)
          ? 'Z5 PEAK'
          : hr >= 160
              ? 'Z4 THRESHOLD'
              : hr >= 145
                  ? 'Z3 TEMPO'
                  : hr >= 130
                      ? 'Z2 ENDURANCE'
                      : 'Z1 RECOVERY';

      final cadenceBase = isCycling ? 88 : 110;
      final cadence = ((cadenceBase / (effortFactor > 1.15 ? 1.12 : 1.0)) + (math.cos(_simStep * 1.2) * 2)).round().clamp(50, 130);

      final powerBase = isCycling ? 245 : 125;
      final power = ((powerBase * effortFactor) + (math.sin(_simStep * 1.5) * 15)).round().clamp(
        isCycling ? 120 : 60,
        isCycling ? 550 : 250,
      );
      final ftpPercent = ((power / (isCycling ? 275.0 : 130.0)) * 100).round();
      final wKg = double.parse((power / 72.0).toStringAsFixed(1));

      _currentData = _currentData.copyWith(
        currentSpeedKmH: double.parse(currentSpeed.toStringAsFixed(1)),
        avgSpeedKmH: isCycling ? 23.8 : 3.8,
        maxSpeedKmH: isCycling ? 58.4 : 7.2,
        currentElevationM: double.parse(nextEle.toStringAsFixed(1)),
        currentGradePercent: double.parse(nextGrade.toStringAsFixed(1)),
        vamAscentRateMh: vam,
        apexElevationM: apex,
        maxGradePercent: double.parse(maxGrade.toStringAsFixed(1)),
        ascentRemainingM: double.parse(remainingAscent.toStringAsFixed(0)),
        heartRateBpm: hr,
        heartRateZone: hrZone,
        isHeartRatePeakAlert: isPeakHr,
        cadenceRpm: cadence,
        powerWatts: power,
        powerFtpPercent: ftpPercent,
        wattsPerKg: wKg,
        distanceTraveledKm: double.parse(nextDistanceTraveled.toStringAsFixed(2)),
        distanceRemainingKm: double.parse(distanceLeft.toStringAsFixed(1)),
        totalDistanceKm: totalDist,
        etaFormatted: eta,
        currentLatitude: gpsPos.latitude,
        currentLongitude: gpsPos.longitude,
        currentHeadingDegrees: heading,
      );

      notifyListeners();
    });
  }

  static (double elevation, double grade) interpolateElevationAndGrade(
    List<ElevationPoint> profile,
    double distKm,
  ) {
    if (profile.isEmpty) return (1000.0, 0.0);
    if (distKm <= profile.first.distanceKm) {
      return (profile.first.elevationM, profile.first.gradePercent);
    }
    if (distKm >= profile.last.distanceKm) {
      return (profile.last.elevationM, profile.last.gradePercent);
    }

    for (int i = 0; i < profile.length - 1; i++) {
      final p1 = profile[i];
      final p2 = profile[i + 1];
      if (distKm >= p1.distanceKm && distKm <= p2.distanceKm) {
        final span = p2.distanceKm - p1.distanceKm;
        final t = span > 0 ? (distKm - p1.distanceKm) / span : 0.0;
        final ele = p1.elevationM + t * (p2.elevationM - p1.elevationM);
        final grade = p1.gradePercent + t * (p2.gradePercent - p1.gradePercent);
        return (ele, grade);
      }
    }
    return (profile.last.elevationM, profile.last.gradePercent);
  }

  static double computeRemainingAscent(
    List<ElevationPoint> profile,
    double currentDistKm,
    double currentEle,
  ) {
    if (profile.isEmpty) return 0.0;
    double remainingAscent = 0.0;
    double lastElevation = currentEle;

    for (final p in profile) {
      if (p.distanceKm > currentDistKm) {
        if (p.elevationM > lastElevation) {
          remainingAscent += (p.elevationM - lastElevation);
        }
        lastElevation = p.elevationM;
      }
    }
    return remainingAscent;
  }

  static (LatLng position, double heading) _interpolateGpsPosition(
    List<LatLng> coords,
    double progress,
    double fallbackHeading,
  ) {
    if (coords.isEmpty) {
      return (const LatLng(47.912, 7.898), fallbackHeading);
    }
    if (coords.length == 1) {
      return (coords.first, fallbackHeading);
    }

    final pClamped = progress.clamp(0.0, 1.0);
    final idxFloat = pClamped * (coords.length - 1);
    final idx = idxFloat.floor();
    final t = idxFloat - idx;

    if (idx >= coords.length - 1) {
      final heading = _calculateBearing(coords[coords.length - 2], coords.last);
      return (coords.last, heading);
    }

    final p1 = coords[idx];
    final p2 = coords[idx + 1];
    final lat = p1.latitude + t * (p2.latitude - p1.latitude);
    final lon = p1.longitude + t * (p2.longitude - p1.longitude);
    final heading = _calculateBearing(p1, p2);
    return (LatLng(lat, lon), heading);
  }

  static double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitudeInRad;
    final lat2 = end.latitudeInRad;
    final dLon = (end.longitude - start.longitude) * (math.pi / 180.0);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final radians = math.atan2(y, x);
    final degrees = (radians * (180.0 / math.pi) + 360.0) % 360.0;
    return degrees;
  }

  static (double apex, double maxGrade) _extractApexAndMaxGrade(RouteModel route) {
    double apex = route.maxElevationM;
    double maxGrade = 0.0;
    for (final pt in route.elevationProfile) {
      if (pt.elevationM > apex) apex = pt.elevationM;
      if (pt.gradePercent > maxGrade) maxGrade = pt.gradePercent;
    }
    if (maxGrade == 0.0) maxGrade = 12.0;
    return (apex, maxGrade);
  }

  static int _calculateVam(double speedKmH, double gradePercent) {
    if (gradePercent <= 0) return 0;
    return (speedKmH * (gradePercent / 100.0) * 1000.0).round();
  }

  static String _formatEta(double distLeftKm, double currentSpeedKmH, ActivityType activity) {
    final minSpeed = activity == ActivityType.cycling ? 15.0 : 3.0;
    final speed = currentSpeedKmH > 1.0 ? currentSpeedKmH : minSpeed;
    final minutesRemaining = (distLeftKm / speed) * 60;
    final targetTime = DateTime.now().add(Duration(minutes: minutesRemaining.round()));
    final hour = targetTime.hour;
    final minute = targetTime.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final formattedHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$formattedHour:$minute $amPm';
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  @override
  void dispose() {
    stopSimulation();
    super.dispose();
  }
}
