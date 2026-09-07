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
import '../location/location_service.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;

class TelemetryService extends ChangeNotifier {
  TelemetryData _currentData = const TelemetryData();
  RouteModel? _activeRoute;
  ActivityType _activityType = ActivityType.cycling;
  Timer? _simulationTimer;
  StreamSubscription<Position>? _gpsSubscription;
  LatLng? _lastKnownGpsPosition;
  bool _isGpsActive = false;
  bool _isRecording = true;
  double _simStep = 0;

  LatLng? get userLocation => _lastKnownGpsPosition;
  bool get isGpsActive => _isGpsActive;

  TelemetryService({RouteModel? initialRoute, bool autoStartSimulation = false}) {
    _activeRoute = initialRoute;
    if (_activeRoute != null) {
      _activityType = _activeRoute!.activityType;
      _initTelemetryFromRoute(_activeRoute!, initialDistanceKm: 0.0);
    } else {
      _currentData = const TelemetryData(
        currentSpeedKmH: 0.0,
        avgSpeedKmH: 0.0,
        maxSpeedKmH: 0.0,
        currentElevationM: 0.0,
        currentGradePercent: 0.0,
        distanceTraveledKm: 0.0,
        distanceRemainingKm: 0.0,
        totalDistanceKm: 0.0,
        heartRateBpm: null,
        heartRateZone: 'STANDBY',
        cadenceRpm: null,
        powerWatts: null,
        wattsPerKg: null,
      );
    }
    if (autoStartSimulation) {
      startSimulation();
    } else {
      initGpsTracking();
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
    if (status.isLocationGranted) {
      initGpsTracking(force: true);
    }
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
    if (_activityType == type) return;
    _activityType = type;
    if (_activeRoute != null) {
      _initTelemetryFromRoute(_activeRoute!, initialDistanceKm: _currentData.distanceTraveledKm);
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

    final userLat = _lastKnownGpsPosition?.latitude ?? (route.coordinates.isNotEmpty ? route.coordinates.first.latitude : gpsPos.latitude);
    final userLon = _lastKnownGpsPosition?.longitude ?? (route.coordinates.isNotEmpty ? route.coordinates.first.longitude : gpsPos.longitude);

    _currentData = _currentData.copyWith(
      currentSpeedKmH: 0.0,
      avgSpeedKmH: 0.0,
      maxSpeedKmH: 0.0,
      currentElevationM: double.parse(curEle.toStringAsFixed(1)),
      currentGradePercent: double.parse(curGrade.toStringAsFixed(1)),
      vamAscentRateMh: 0,
      apexElevationM: apex,
      maxGradePercent: double.parse(maxGrade.toStringAsFixed(1)),
      ascentRemainingM: double.parse(ascentLeft.toStringAsFixed(0)),
      totalDistanceKm: route.totalDistanceKm,
      distanceTraveledKm: double.parse(distTraveled.toStringAsFixed(2)),
      distanceRemainingKm: double.parse(distLeft.toStringAsFixed(1)),
      etaFormatted: '--:--',
      currentLatitude: userLat,
      currentLongitude: userLon,
      currentHeadingDegrees: heading,
      heartRateBpm: null,
      heartRateZone: 'STANDBY',
      isHeartRatePeakAlert: false,
      cadenceRpm: null,
      powerWatts: null,
      powerFtpPercent: 0,
      wattsPerKg: null,
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

  /// Initializes live hardware GPS tracking from the device sensor
  Future<void> initGpsTracking({bool force = false}) async {
    if (_gpsSubscription != null && !force) return;
    if (force) {
      await _gpsSubscription?.cancel();
      _gpsSubscription = null;
    }

    try {
      // 1. Instant fix from last known position (sub-second)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && _lastKnownGpsPosition == null) {
        _onGpsPositionUpdate(lastKnown);
      }

      // 2. Fresh high-accuracy fix
      final initialFix = await LocationService.getCurrentPosition();
      if (initialFix != null) {
        _onGpsPositionUpdate(initialFix);
      }

      // 3. Continuous real-time GPS stream (distanceFilter: 0 for continuous telemetry updates)
      _gpsSubscription = LocationService.getPositionStream(distanceFilterMeters: 0).listen(
        (pos) {
          _onGpsPositionUpdate(pos);
        },
        onError: (err) {
          debugPrint('[TelemetryService] GPS stream error: $err');
          _isGpsActive = false;
          _gpsSubscription?.cancel();
          _gpsSubscription = null;
          notifyListeners();
        },
      );
      _isGpsActive = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[TelemetryService] Error initializing GPS tracking: $e');
    }
  }

  void _onGpsPositionUpdate(Position pos) {
    final userGps = LatLng(pos.latitude, pos.longitude);
    _lastKnownGpsPosition = userGps;

    // Real GPS speed in km/h (speed is in m/s from Geolocator)
    final rawSpeedKmH = pos.speed * 3.6;
    // Suppress GPS jitter/drift when stationary (< 0.8 km/h or negative)
    final realSpeedKmH = (rawSpeedKmH >= 0.8 && pos.speed >= 0) ? rawSpeedKmH : 0.0;

    final realEle = pos.altitude;
    final realHeading = pos.heading >= 0 ? pos.heading : _currentData.currentHeadingDegrees;

    if (_activeRoute != null && _activeRoute!.coordinates.isNotEmpty) {
      final projection = LocationService.projectOntoRoute(userGps, _activeRoute!.coordinates);
      final (curEle, curGrade) = interpolateElevationAndGrade(
        _activeRoute!.elevationProfile,
        projection.distanceTraveledKm,
      );
      final ascentLeft = computeRemainingAscent(
        _activeRoute!.elevationProfile,
        projection.distanceTraveledKm,
        curEle,
      );
      final (apex, maxGrade) = _extractApexAndMaxGrade(_activeRoute!);
      final vam = _calculateVam(realSpeedKmH, curGrade);
      final eta = _formatEta(projection.distanceRemainingKm, realSpeedKmH, _activityType);

      _currentData = _currentData.copyWith(
        currentLatitude: pos.latitude,
        currentLongitude: pos.longitude,
        currentHeadingDegrees: realHeading,
        currentSpeedKmH: double.parse(realSpeedKmH.toStringAsFixed(1)),
        currentElevationM: realEle > 0 ? double.parse(realEle.toStringAsFixed(1)) : curEle,
        currentGradePercent: double.parse(curGrade.toStringAsFixed(1)),
        distanceTraveledKm: double.parse(projection.distanceTraveledKm.toStringAsFixed(2)),
        distanceRemainingKm: double.parse(projection.distanceRemainingKm.toStringAsFixed(1)),
        totalDistanceKm: _activeRoute!.totalDistanceKm,
        ascentRemainingM: double.parse(ascentLeft.toStringAsFixed(0)),
        apexElevationM: apex,
        maxGradePercent: double.parse(maxGrade.toStringAsFixed(1)),
        vamAscentRateMh: vam,
        etaFormatted: eta,
        isOffRoute: projection.distanceOffRouteMeters > 40,
        crossTrackDistanceM: double.parse(projection.distanceOffRouteMeters.toStringAsFixed(1)),
        gpsAccuracyM: double.parse(pos.accuracy.toStringAsFixed(1)),
        // Biometrics remain in standby awaiting smartwatch pairing
        heartRateBpm: null,
        heartRateZone: 'STANDBY',
        cadenceRpm: null,
        powerWatts: null,
        wattsPerKg: null,
      );
    } else {
      _currentData = _currentData.copyWith(
        currentLatitude: pos.latitude,
        currentLongitude: pos.longitude,
        currentHeadingDegrees: realHeading,
        currentSpeedKmH: double.parse(realSpeedKmH.toStringAsFixed(1)),
        currentElevationM: double.parse(realEle.toStringAsFixed(1)),
        currentGradePercent: 0.0,
        distanceTraveledKm: 0.0,
        distanceRemainingKm: 0.0,
        gpsAccuracyM: double.parse(pos.accuracy.toStringAsFixed(1)),
        heartRateBpm: null,
        heartRateZone: 'STANDBY',
        cadenceRpm: null,
        powerWatts: null,
        wattsPerKg: null,
      );
    }

    notifyListeners();
  }

  void stopSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    stopSimulation();
    super.dispose();
  }
}
