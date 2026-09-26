import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' hide Path;

enum ManeuverType {
  hairpinLeft,
  hairpinRight,
  turnLeft,
  turnRight,
  slightLeft,
  slightRight,
  straight,
  uTurn,
  destination,
}

class ManeuverInstruction {
  final int distanceToManeuverMeters;
  final ManeuverType maneuverType;
  final String instructionTitle;
  final String trailName;
  final String surfaceType;
  final double apexElevationM;
  final LatLng? coordinate;
  final double distanceAlongRouteM;
  final int stepIndex;
  final bool hasAlertedApproach;
  final bool hasAlertedImmediate;

  const ManeuverInstruction({
    this.distanceToManeuverMeters = 140,
    this.maneuverType = ManeuverType.hairpinLeft,
    this.instructionTitle = 'Hairpin Left',
    this.trailName = 'Schauinsland Ridge',
    this.surfaceType = 'Compact Gravel',
    this.apexElevationM = 2191.0,
    this.coordinate,
    this.distanceAlongRouteM = 0.0,
    this.stepIndex = 0,
    this.hasAlertedApproach = false,
    this.hasAlertedImmediate = false,
  });

  ManeuverInstruction copyWith({
    int? distanceToManeuverMeters,
    ManeuverType? maneuverType,
    String? instructionTitle,
    String? trailName,
    String? surfaceType,
    double? apexElevationM,
    LatLng? coordinate,
    double? distanceAlongRouteM,
    int? stepIndex,
    bool? hasAlertedApproach,
    bool? hasAlertedImmediate,
  }) {
    return ManeuverInstruction(
      distanceToManeuverMeters: distanceToManeuverMeters ?? this.distanceToManeuverMeters,
      maneuverType: maneuverType ?? this.maneuverType,
      instructionTitle: instructionTitle ?? this.instructionTitle,
      trailName: trailName ?? this.trailName,
      surfaceType: surfaceType ?? this.surfaceType,
      apexElevationM: apexElevationM ?? this.apexElevationM,
      coordinate: coordinate ?? this.coordinate,
      distanceAlongRouteM: distanceAlongRouteM ?? this.distanceAlongRouteM,
      stepIndex: stepIndex ?? this.stepIndex,
      hasAlertedApproach: hasAlertedApproach ?? this.hasAlertedApproach,
      hasAlertedImmediate: hasAlertedImmediate ?? this.hasAlertedImmediate,
    );
  }

  IconData get icon {
    switch (maneuverType) {
      case ManeuverType.hairpinLeft:
        return Icons.turn_sharp_left;
      case ManeuverType.hairpinRight:
        return Icons.turn_sharp_right;
      case ManeuverType.turnLeft:
        return Icons.turn_left;
      case ManeuverType.turnRight:
        return Icons.turn_right;
      case ManeuverType.slightLeft:
        return Icons.turn_slight_left;
      case ManeuverType.slightRight:
        return Icons.turn_slight_right;
      case ManeuverType.straight:
        return Icons.straight;
      case ManeuverType.uTurn:
        return Icons.u_turn_left;
      case ManeuverType.destination:
        return Icons.flag;
    }
  }
}
