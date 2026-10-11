import 'dart:math' as math;
import 'package:latlong2/latlong.dart' hide Path;
import '../models/activity_type.dart';
import '../models/maneuver_instruction.dart';
import '../models/route_model.dart';
import 'audio_navigation_service.dart';

/// Real-time turn-by-turn navigation engine with automated turn extraction,
/// live distance countdown, and multi-stage audio alerts inspired by Bikemap and Komoot.
class TurnNavigationEngine {
  final AudioNavigationService _audioService;
  bool _enabled;

  List<ManeuverInstruction> _maneuvers = [];
  int _currentIndex = 0;
  bool _wasOffRoute = false;
  bool _hasArrived = false;

  TurnNavigationEngine({AudioNavigationService? audioService, bool enabled = false})
      : _audioService = audioService ?? AudioNavigationService(),
        _enabled = enabled;

  bool get isEnabled => _enabled;

  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (enabled) {
      _wasOffRoute = false;
    } else {
      _audioService.stopAll();
    }
  }

  void stopAudio() {
    _audioService.stopAll();
  }

  AudioNavigationService get audioService => _audioService;
  List<ManeuverInstruction> get maneuvers => List.unmodifiable(_maneuvers);
  int get currentIndex => _currentIndex;
  ManeuverInstruction? get currentManeuver =>
      _maneuvers.isNotEmpty && _currentIndex < _maneuvers.length
          ? _maneuvers[_currentIndex]
          : null;

  void dispose() {
    _audioService.dispose();
  }

  /// Clears active maneuvers and stops audio guidance
  void resetRoute() {
    _currentIndex = 0;
    _wasOffRoute = false;
    _hasArrived = false;
    _maneuvers = [];
    _audioService.stopAll();
    _enabled = false;
  }

  /// Initializes or resets the engine with a given route.
  /// If the route has no detailed maneuvers, automatically extracts them from coordinates.
  void initRoute(RouteModel route) {
    _currentIndex = 0;
    _wasOffRoute = false;
    _hasArrived = false;

    if (route.maneuvers.length > 1 && route.maneuvers.any((m) => m.distanceAlongRouteM > 0)) {
      _maneuvers = List.from(route.maneuvers);
    } else {
      _maneuvers = extractManeuversFromCoordinates(
        coordinates: route.coordinates,
        activityType: route.activityType,
        routeName: route.name,
      );
    }

    if (_maneuvers.isNotEmpty) {
      _updateManeuverDistance(0.0);
    }
  }

  /// Updates live turn tracking based on cumulative distance traveled along the route
  ManeuverInstruction? updateProgress({
    required double distanceTraveledM,
    required bool isOffRoute,
    required ActivityType activityType,
  }) {
    if (!_enabled || _maneuvers.isEmpty) return null;

    // 1. Check Off-Route Alert (fires on rising edge when entering off-route state)
    if (isOffRoute && !_wasOffRoute) {
      _audioService.playOffRouteAlert();
    }
    _wasOffRoute = isOffRoute;

    // 2. Advance maneuver index when user passes current maneuver location (buffer of 15m)
    while (_currentIndex < _maneuvers.length - 1) {
      final current = _maneuvers[_currentIndex];
      if (distanceTraveledM >= current.distanceAlongRouteM + 15.0) {
        _currentIndex++;
      } else {
        break;
      }
    }

    final activeManeuver = _maneuvers[_currentIndex];
    final remainingM = math.max(0, (activeManeuver.distanceAlongRouteM - distanceTraveledM).round());

    // 3. Multi-stage audio alert thresholds (Bikemap / Komoot model)
    final isCycling = activityType == ActivityType.cycling;
    final approachThresholdM = isCycling ? 85 : 40;
    final immediateThresholdM = isCycling ? 20 : 12;

    ManeuverInstruction updated = activeManeuver.copyWith(
      distanceToManeuverMeters: remainingM,
    );

    // Destination Arrival
    if (activeManeuver.maneuverType == ManeuverType.destination) {
      if (remainingM <= immediateThresholdM && !_hasArrived) {
        _hasArrived = true;
        _audioService.playArrivalAlert();
      }
    } else {
      // Approach Alert (e.g., at ~80m for cycling / ~40m for hiking)
      if (remainingM <= approachThresholdM && !activeManeuver.hasAlertedApproach) {
        updated = updated.copyWith(hasAlertedApproach: true);
        final spoken = 'In $remainingM meters, ${activeManeuver.instructionTitle.toLowerCase()} onto ${activeManeuver.trailName}';
        _audioService.playApproachAlert(spokenText: spoken);
      }

      // Immediate Turn Alert (e.g., at ~18m before turn apex)
      if (remainingM <= immediateThresholdM && !activeManeuver.hasAlertedImmediate) {
        updated = updated.copyWith(hasAlertedImmediate: true);
        final spoken = '${activeManeuver.instructionTitle} now';
        _audioService.playImmediateAlert(spokenText: spoken);
      }
    }

    _maneuvers[_currentIndex] = updated;
    return updated;
  }

  void _updateManeuverDistance(double distanceTraveledM) {
    if (_currentIndex < _maneuvers.length) {
      final current = _maneuvers[_currentIndex];
      final rem = math.max(0, (current.distanceAlongRouteM - distanceTraveledM).round());
      _maneuvers[_currentIndex] = current.copyWith(distanceToManeuverMeters: rem);
    }
  }

  /// Automated maneuver extraction algorithm from GPS trackpoint coordinates
  static List<ManeuverInstruction> extractManeuversFromCoordinates({
    required List<LatLng> coordinates,
    required ActivityType activityType,
    required String routeName,
  }) {
    if (coordinates.isEmpty) {
      return [
        ManeuverInstruction(
          distanceToManeuverMeters: 0,
          maneuverType: ManeuverType.destination,
          instructionTitle: 'Arrived at Destination',
          trailName: routeName,
          surfaceType: 'Trail',
        ),
      ];
    }

    if (coordinates.length < 3) {
      return [
        ManeuverInstruction(
          distanceToManeuverMeters: 100,
          maneuverType: ManeuverType.straight,
          instructionTitle: 'Follow Track',
          trailName: routeName,
          surfaceType: 'Trail',
          distanceAlongRouteM: 0.0,
        ),
        ManeuverInstruction(
          distanceToManeuverMeters: 0,
          maneuverType: ManeuverType.destination,
          instructionTitle: 'Arrived at Destination',
          trailName: routeName,
          surfaceType: 'Trail',
          distanceAlongRouteM: 100.0,
        ),
      ];
    }

    const Distance distanceCalculator = Distance();
    final List<double> cumulativeDistances = [0.0];

    for (int i = 0; i < coordinates.length - 1; i++) {
      final dist = distanceCalculator.as(LengthUnit.Meter, coordinates[i], coordinates[i + 1]);
      cumulativeDistances.add(cumulativeDistances.last + dist);
    }

    final totalRouteDistM = cumulativeDistances.last;
    final maneuvers = <ManeuverInstruction>[];

    // Initial Departure Maneuver
    maneuvers.add(ManeuverInstruction(
      distanceToManeuverMeters: 0,
      maneuverType: ManeuverType.straight,
      instructionTitle: 'Depart on Route',
      trailName: routeName,
      surfaceType: activityType == ActivityType.cycling ? 'Cycle Track' : 'Mountain Trail',
      coordinate: coordinates.first,
      distanceAlongRouteM: 0.0,
      stepIndex: 0,
    ));

    // Sample along coordinates with minimum step interval (~25m) to filter micro-jitter
    final sampleIndices = <int>[0];
    double lastSampleDist = 0.0;
    for (int i = 1; i < coordinates.length; i++) {
      if (cumulativeDistances[i] - lastSampleDist >= 25.0 || i == coordinates.length - 1) {
        sampleIndices.add(i);
        lastSampleDist = cumulativeDistances[i];
      }
    }

    double lastManeuverDist = 0.0;
    int stepIdx = 1;

    for (int s = 1; s < sampleIndices.length - 1; s++) {
      final prevIdx = sampleIndices[s - 1];
      final currIdx = sampleIndices[s];
      final nextIdx = sampleIndices[s + 1];

      final pPrev = coordinates[prevIdx];
      final pCurr = coordinates[currIdx];
      final pNext = coordinates[nextIdx];

      final currentDistM = cumulativeDistances[currIdx];

      // Enforce minimum gap between turns (40m) to group compound corners
      if (currentDistM - lastManeuverDist < 40.0) continue;

      final b1 = _calculateBearing(pPrev, pCurr);
      final b2 = _calculateBearing(pCurr, pNext);
      final delta = _normalizeAngleDelta(b2 - b1);

      final absDelta = delta.abs();
      if (absDelta >= 22.0) {
        final (type, title) = _classifyTurn(delta);

        maneuvers.add(ManeuverInstruction(
          distanceToManeuverMeters: (currentDistM).round(),
          maneuverType: type,
          instructionTitle: title,
          trailName: routeName,
          surfaceType: activityType == ActivityType.cycling ? 'Cycle Track' : 'Mountain Trail',
          coordinate: pCurr,
          distanceAlongRouteM: currentDistM,
          stepIndex: stepIdx++,
        ));

        lastManeuverDist = currentDistM;
      }
    }

    // Final Destination Maneuver
    maneuvers.add(ManeuverInstruction(
      distanceToManeuverMeters: totalRouteDistM.round(),
      maneuverType: ManeuverType.destination,
      instructionTitle: 'Arrived at Destination',
      trailName: routeName,
      surfaceType: activityType == ActivityType.cycling ? 'Paved Way' : 'Trailhead',
      coordinate: coordinates.last,
      distanceAlongRouteM: totalRouteDistM,
      stepIndex: stepIdx,
    ));

    return maneuvers;
  }

  static double _calculateBearing(LatLng p1, LatLng p2) {
    final lat1 = p1.latitudeInRad;
    final lat2 = p2.latitudeInRad;
    final dLon = (p2.longitude - p1.longitude) * (math.pi / 180.0);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    final bRad = math.atan2(y, x);
    return (bRad * (180.0 / math.pi) + 360.0) % 360.0;
  }

  static double _normalizeAngleDelta(double delta) {
    while (delta > 180.0) {
      delta -= 360.0;
    }
    while (delta < -180.0) {
      delta += 360.0;
    }
    return delta;
  }

  static (ManeuverType, String) _classifyTurn(double delta) {
    if (delta > 115.0) {
      return (ManeuverType.hairpinRight, 'Sharp Right');
    } else if (delta > 45.0) {
      return (ManeuverType.turnRight, 'Turn Right');
    } else if (delta > 20.0) {
      return (ManeuverType.slightRight, 'Slight Right');
    } else if (delta < -115.0) {
      return (ManeuverType.hairpinLeft, 'Sharp Left');
    } else if (delta < -45.0) {
      return (ManeuverType.turnLeft, 'Turn Left');
    } else {
      return (ManeuverType.slightLeft, 'Slight Left');
    }
  }
}
