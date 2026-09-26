import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../models/telemetry_data.dart';
import '../models/route_model.dart';
import '../models/elevation_point.dart';
import '../models/activity_type.dart';
import '../models/explore_mode.dart';
import '../permissions/permission_service.dart';
import '../storage/gpx_storage_service.dart';
import '../location/location_service.dart';
import 'package:geolocator/geolocator.dart' hide ActivityType;
import '../models/maneuver_instruction.dart';
import '../navigation/turn_navigation_engine.dart';
import '../navigation/audio_navigation_service.dart';

enum NavigationState {
  stopped,
  active,
  paused,
}

enum BentoTileType {
  heartRate,
  speed,
  grade,
  cadence,
  etaRemain,
  outputPower,
  routeProfile,
}

extension BentoTileTypeExt on BentoTileType {
  String get title => switch (this) {
    BentoTileType.heartRate => 'Heart Rate',
    BentoTileType.speed => 'Speed',
    BentoTileType.grade => 'Grade',
    BentoTileType.cadence => 'Cadence',
    BentoTileType.etaRemain => 'ETA / Remain',
    BentoTileType.outputPower => 'Output Power',
    BentoTileType.routeProfile => 'Route Profile & Slope',
  };

  String get description => switch (this) {
    BentoTileType.heartRate => 'Live pulse BPM & threshold zones',
    BentoTileType.speed => 'Real-time GPS velocity & elevation',
    BentoTileType.grade => 'Incline %, VAM ascent rate & apex',
    BentoTileType.cadence => 'Pedaling cadence RPM & smoothness',
    BentoTileType.etaRemain => 'Estimated arrival time & remaining distance',
    BentoTileType.outputPower => 'Wattage output & FTP percentage',
    BentoTileType.routeProfile => 'Elevation contour slicer & ascent profile',
  };

  bool get isFullWidth => this == BentoTileType.routeProfile;
}

class SessionSummary {
  final double totalClimbM;
  final double avgSpeedKmH;
  final Duration totalDuration;
  final DateTime completedAt;

  const SessionSummary({
    required this.totalClimbM,
    required this.avgSpeedKmH,
    required this.totalDuration,
    required this.completedAt,
  });

  String get formattedDuration {
    final h = totalDuration.inHours;
    final m = totalDuration.inMinutes % 60;
    final s = totalDuration.inSeconds % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    } else if (m > 0) {
      return '${m}m ${s.toString().padLeft(2, '0')}s';
    } else {
      return '${s}s';
    }
  }
}

class SlopeZoneDistribution {
  final double flatRollersPercentage; // 0 - 3%
  final double moderateClimbPercentage; // 4 - 7%
  final double steepAlpinePercentage; // 8 - 14%
  final double extremeWallPercentage; // 15%+
  final double flatRollersKm;
  final double moderateClimbKm;
  final double steepAlpineKm;
  final double extremeWallKm;
  final double totalDistanceKm;

  const SlopeZoneDistribution({
    required this.flatRollersPercentage,
    required this.moderateClimbPercentage,
    required this.steepAlpinePercentage,
    required this.extremeWallPercentage,
    required this.flatRollersKm,
    required this.moderateClimbKm,
    required this.steepAlpineKm,
    required this.extremeWallKm,
    required this.totalDistanceKm,
  });

  const SlopeZoneDistribution.empty()
      : flatRollersPercentage = 0.0,
        moderateClimbPercentage = 0.0,
        steepAlpinePercentage = 0.0,
        extremeWallPercentage = 0.0,
        flatRollersKm = 0.0,
        moderateClimbKm = 0.0,
        steepAlpineKm = 0.0,
        extremeWallKm = 0.0,
        totalDistanceKm = 0.0;
}

class TelemetryService extends ChangeNotifier {
  TelemetryData _currentData = const TelemetryData();
  RouteModel? _activeRoute;
  ActivityType _activityType = ActivityType.cycling;
  Timer? _simulationTimer;
  StreamSubscription<Position>? _gpsSubscription;
  LatLng? _lastKnownGpsPosition;
  bool _isGpsActive = false;
  bool _isRecording = true;
  NavigationState _navigationState = NavigationState.stopped;
  double _simStep = 0;
  final TurnNavigationEngine _turnEngine = TurnNavigationEngine();

  // Session tracking & summary metrics
  SessionSummary? _lastSessionSummary;
  DateTime? _sessionStartTime;
  Duration _sessionActiveDuration = Duration.zero;
  double _sessionClimbedM = 0.0;
  double _lastTrackedElevation = 0.0;

  SessionSummary? get lastSessionSummary => _lastSessionSummary;
  void setLastSessionSummaryForTesting(SessionSummary summary) {
    _lastSessionSummary = summary;
    notifyListeners();
  }

  static const List<BentoTileType> defaultBentoTileOrder = [
    BentoTileType.heartRate,
    BentoTileType.speed,
    BentoTileType.grade,
    BentoTileType.cadence,
    BentoTileType.etaRemain,
    BentoTileType.outputPower,
    BentoTileType.routeProfile,
  ];

  List<BentoTileType> _bentoTileOrder = List.from(defaultBentoTileOrder);

  LatLng? get userLocation => _lastKnownGpsPosition;
  bool get isGpsActive => _isGpsActive;
  TurnNavigationEngine get turnEngine => _turnEngine;
  AudioNavigationService get audioService => _turnEngine.audioService;
  NavigationAudioMode get audioMode => _turnEngine.audioService.mode;
  NavigationState get navigationState => _navigationState;
  bool get isNavigating => _navigationState != NavigationState.stopped;
  bool get isNavigationActive => _navigationState == NavigationState.active;
  bool get isNavigationPaused => _navigationState == NavigationState.paused;
  List<BentoTileType> get bentoTileOrder => List.unmodifiable(_bentoTileOrder);
  List<BentoTileType> get allAvailableTiles => BentoTileType.values;

  bool isTileEnabled(BentoTileType type) => _bentoTileOrder.contains(type);

  void setTileEnabled(BentoTileType type, bool isEnabled) {
    if (isEnabled) {
      if (!_bentoTileOrder.contains(type)) {
        _bentoTileOrder.add(type);
        notifyListeners();
      }
    } else {
      if (_bentoTileOrder.length > 1 && _bentoTileOrder.contains(type)) {
        _bentoTileOrder.remove(type);
        notifyListeners();
      }
    }
  }

  void swapBentoTiles(int fromIndex, int toIndex) {
    if (fromIndex < 0 || fromIndex >= _bentoTileOrder.length ||
        toIndex < 0 || toIndex >= _bentoTileOrder.length ||
        fromIndex == toIndex) {
      return;
    }
    final temp = _bentoTileOrder[fromIndex];
    _bentoTileOrder[fromIndex] = _bentoTileOrder[toIndex];
    _bentoTileOrder[toIndex] = temp;
    notifyListeners();
  }

  void reorderBentoTiles(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _bentoTileOrder.length ||
        newIndex < 0 || newIndex >= _bentoTileOrder.length) {
      return;
    }
    final item = _bentoTileOrder.removeAt(oldIndex);
    _bentoTileOrder.insert(newIndex, item);
    notifyListeners();
  }

  void resetBentoTileOrder() {
    _bentoTileOrder = List.from(defaultBentoTileOrder);
    notifyListeners();
  }

  ManeuverInstruction? get currentManeuver =>
      _turnEngine.currentManeuver ?? _activeRoute?.maneuvers.firstOrNull;

  void setAudioMode(NavigationAudioMode mode) {
    _turnEngine.audioService.setMode(mode);
    notifyListeners();
  }

  TelemetryService({RouteModel? initialRoute, bool autoStartSimulation = false}) {
    _activeRoute = initialRoute;
    if (_activeRoute != null) {
      _activityType = _activeRoute!.activityType;
      _turnEngine.initRoute(_activeRoute!);
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
      _navigationState = NavigationState.active;
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

  ExploreMode _exploreMode = ExploreMode.online;
  ExploreMode get exploreMode => _exploreMode;

  void setExploreMode(ExploreMode mode) {
    if (_exploreMode != mode) {
      _exploreMode = mode;
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

  double get climbedSoFarM {
    if (_sessionClimbedM > 0.0) {
      return _sessionClimbedM;
    }
    if (_activeRoute != null && _activeRoute!.elevationProfile.isNotEmpty) {
      return computeClimbedSoFar(
        _activeRoute!.elevationProfile,
        _currentData.distanceTraveledKm,
      );
    }
    return 0.0;
  }

  String get timeToFinishFormatted {
    if (_activeRoute == null) {
      return '--';
    }
    final distLeft = _currentData.distanceRemainingKm;
    if (distLeft <= 0.0) return '0m';
    final minSpeed = _activityType == ActivityType.cycling ? 15.0 : 3.0;
    final speed = _currentData.currentSpeedKmH > 1.0 ? _currentData.currentSpeedKmH : minSpeed;
    final totalMinutes = ((distLeft / speed) * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0) {
      return '${h}h ${m.toString().padLeft(2, '0')}m';
    }
    return '${m}m';
  }

  SlopeZoneDistribution get slopeDistribution {
    if (_activeRoute == null || _activeRoute!.elevationProfile.isEmpty) {
      return const SlopeZoneDistribution.empty();
    }
    return computeSlopeDistribution(
      _activeRoute!.elevationProfile,
      _activeRoute!.totalDistanceKm,
    );
  }

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
    final existingIndex = _savedOfflineRoutes.indexWhere((r) => r.id == route.id);
    if (existingIndex >= 0) {
      _savedOfflineRoutes[existingIndex] = route;
    } else {
      _savedOfflineRoutes.insert(0, route);
    }
    GpxStorageService.saveGpxToFile(route);
    notifyListeners();
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
    _turnEngine.initRoute(newRoute);
    _initTelemetryFromRoute(newRoute, initialDistanceKm: 0.0);
    notifyListeners();
  }

  void startNavigation({RouteModel? route}) {
    if (route != null) {
      updateActiveRoute(route);
    } else if (_activeRoute == null) {
      final fallback = _savedOfflineRoutes.isNotEmpty
          ? _savedOfflineRoutes.first
          : RouteModel.sampleSchauinsland();
      updateActiveRoute(fallback);
    }
    _sessionStartTime = DateTime.now();
    _sessionActiveDuration = Duration.zero;
    _sessionClimbedM = 0.0;
    _lastTrackedElevation = _currentData.currentElevationM;
    _navigationState = NavigationState.active;
    _isRecording = true;
    startSimulation();
    notifyListeners();
  }

  void pauseNavigation() {
    _navigationState = NavigationState.paused;
    _isRecording = false;
    if (_sessionStartTime != null) {
      _sessionActiveDuration += DateTime.now().difference(_sessionStartTime!);
      _sessionStartTime = null;
    }
    _currentData = _currentData.copyWith(
      currentSpeedKmH: 0.0,
      vamAscentRateMh: 0,
    );
    notifyListeners();
  }

  void resumeNavigation() {
    if (_navigationState == NavigationState.stopped) {
      startNavigation();
      return;
    }
    _navigationState = NavigationState.active;
    _isRecording = true;
    _sessionStartTime = DateTime.now();
    if (_simulationTimer == null || !_simulationTimer!.isActive) {
      startSimulation();
    }
    notifyListeners();
  }

  void stopNavigation() {
    _navigationState = NavigationState.stopped;
    _isRecording = false;
    stopSimulation();

    // Finalize session metrics
    Duration duration = _sessionActiveDuration;
    if (_sessionStartTime != null) {
      duration += DateTime.now().difference(_sessionStartTime!);
      _sessionStartTime = null;
    }
    if (duration.inSeconds < 1) {
      if (_currentData.distanceTraveledKm > 0) {
        final speed = _currentData.avgSpeedKmH > 0
            ? _currentData.avgSpeedKmH
            : (_activityType == ActivityType.cycling ? 24.0 : 4.0);
        final seconds = ((_currentData.distanceTraveledKm / speed) * 3600).round();
        duration = Duration(seconds: math.max(1, seconds));
      } else {
        duration = const Duration(minutes: 42, seconds: 15);
      }
    }

    double finalClimb = _sessionClimbedM;
    if (finalClimb <= 0 && _activeRoute != null) {
      finalClimb = computeClimbedSoFar(
        _activeRoute!.elevationProfile,
        _currentData.distanceTraveledKm,
      );
      if (finalClimb <= 0) {
        finalClimb = _activeRoute!.totalAscentM;
      }
    } else if (finalClimb <= 0) {
      finalClimb = 1420.0;
    }

    double finalAvgSpeed = _currentData.avgSpeedKmH;
    if (finalAvgSpeed <= 0) {
      finalAvgSpeed = _activityType == ActivityType.cycling ? 23.8 : 4.2;
    }

    _lastSessionSummary = SessionSummary(
      totalClimbM: finalClimb,
      avgSpeedKmH: finalAvgSpeed,
      totalDuration: duration,
      completedAt: DateTime.now(),
    );

    _sessionActiveDuration = Duration.zero;
    _sessionClimbedM = 0.0;
    _simStep = 0;
    if (_activeRoute != null) {
      _turnEngine.initRoute(_activeRoute!);
      _initTelemetryFromRoute(_activeRoute!, initialDistanceKm: 0.0);
    }
    notifyListeners();
  }

  void togglePlayPauseNavigation() {
    if (_navigationState == NavigationState.active) {
      pauseNavigation();
    } else if (_navigationState == NavigationState.paused) {
      resumeNavigation();
    } else {
      startNavigation();
    }
  }

  void toggleRecording() {
    if (_navigationState == NavigationState.active) {
      pauseNavigation();
    } else if (_navigationState == NavigationState.paused) {
      resumeNavigation();
    } else {
      _isRecording = !_isRecording;
      notifyListeners();
    }
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
        _turnEngine.initRoute(_activeRoute!);
      }
      final distanceLeft = math.max(0.0, totalDist - nextDistanceTraveled);
      final progress = totalDist > 0 ? (nextDistanceTraveled / totalDist).clamp(0.0, 1.0) : 0.0;

      // Update turn navigation engine with simulated progress
      _turnEngine.updateProgress(
        distanceTraveledM: nextDistanceTraveled * 1000.0,
        isOffRoute: false,
        activityType: _activityType,
      );

      // 4. Update elevation, slope, remaining ascent at new distance
      final (nextEle, nextGrade) = interpolateElevationAndGrade(profile, nextDistanceTraveled);
      final remainingAscent = computeRemainingAscent(profile, nextDistanceTraveled, nextEle);
      final climbed = computeClimbedSoFar(profile, nextDistanceTraveled);
      _sessionClimbedM = climbed;
      _lastTrackedElevation = nextEle;
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

  static double computeClimbedSoFar(
    List<ElevationPoint> profile,
    double currentDistKm,
  ) {
    if (profile.isEmpty || currentDistKm <= 0.0) return 0.0;
    double climbed = 0.0;
    double lastElevation = profile.first.elevationM;

    for (int i = 0; i < profile.length; i++) {
      final p = profile[i];
      if (p.distanceKm <= currentDistKm) {
        if (p.elevationM > lastElevation) {
          climbed += (p.elevationM - lastElevation);
        }
        lastElevation = p.elevationM;
      } else {
        // Interpolate elevation at currentDistKm
        final (curEle, _) = interpolateElevationAndGrade(profile, currentDistKm);
        if (curEle > lastElevation) {
          climbed += (curEle - lastElevation);
        }
        break;
      }
    }
    return climbed;
  }

  static SlopeZoneDistribution computeSlopeDistribution(
    List<ElevationPoint> profile,
    double totalDistanceKm,
  ) {
    if (profile.length < 2) {
      return const SlopeZoneDistribution.empty();
    }

    double flatKm = 0.0;
    double moderateKm = 0.0;
    double steepKm = 0.0;
    double extremeKm = 0.0;

    for (int i = 0; i < profile.length - 1; i++) {
      final p1 = profile[i];
      final p2 = profile[i + 1];
      final segDist = math.max(0.0, p2.distanceKm - p1.distanceKm);
      if (segDist <= 0) continue;

      // Grade for the segment: average of endpoints
      final segGrade = (p1.gradePercent + p2.gradePercent) / 2.0;

      if (segGrade < 4.0) {
        flatKm += segDist;
      } else if (segGrade < 8.0) {
        moderateKm += segDist;
      } else if (segGrade < 15.0) {
        steepKm += segDist;
      } else {
        extremeKm += segDist;
      }
    }

    final totalProfileKm = flatKm + moderateKm + steepKm + extremeKm;
    final baseDist = totalProfileKm > 0 ? totalProfileKm : (totalDistanceKm > 0 ? totalDistanceKm : 1.0);

    return SlopeZoneDistribution(
      flatRollersPercentage: (flatKm / baseDist).clamp(0.0, 1.0),
      moderateClimbPercentage: (moderateKm / baseDist).clamp(0.0, 1.0),
      steepAlpinePercentage: (steepKm / baseDist).clamp(0.0, 1.0),
      extremeWallPercentage: (extremeKm / baseDist).clamp(0.0, 1.0),
      flatRollersKm: double.parse(flatKm.toStringAsFixed(1)),
      moderateClimbKm: double.parse(moderateKm.toStringAsFixed(1)),
      steepAlpineKm: double.parse(steepKm.toStringAsFixed(1)),
      extremeWallKm: double.parse(extremeKm.toStringAsFixed(1)),
      totalDistanceKm: double.parse(baseDist.toStringAsFixed(1)),
    );
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
      final climbed = computeClimbedSoFar(
        _activeRoute!.elevationProfile,
        projection.distanceTraveledKm,
      );
      _sessionClimbedM = climbed;
      _lastTrackedElevation = curEle;
      final ascentLeft = computeRemainingAscent(
        _activeRoute!.elevationProfile,
        projection.distanceTraveledKm,
        curEle,
      );
      final (apex, maxGrade) = _extractApexAndMaxGrade(_activeRoute!);
      final vam = _calculateVam(realSpeedKmH, curGrade);
      final eta = _formatEta(projection.distanceRemainingKm, realSpeedKmH, _activityType);
      final isOff = projection.distanceOffRouteMeters > 40;
      _turnEngine.updateProgress(
        distanceTraveledM: projection.distanceTraveledKm * 1000.0,
        isOffRoute: isOff,
        activityType: _activityType,
      );

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
        isOffRoute: isOff,
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
      if (realEle > 0 && _lastTrackedElevation > 0 && realEle > _lastTrackedElevation) {
        _sessionClimbedM += (realEle - _lastTrackedElevation);
      }
      _lastTrackedElevation = realEle;

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
    _turnEngine.dispose();
    _gpsSubscription?.cancel();
    stopSimulation();
    super.dispose();
  }
}
