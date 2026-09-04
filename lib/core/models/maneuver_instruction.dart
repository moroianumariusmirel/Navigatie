import 'package:flutter/material.dart';

enum ManeuverType {
  hairpinLeft,
  hairpinRight,
  turnLeft,
  turnRight,
  slightLeft,
  slightRight,
  straight,
  uTurn,
}

class ManeuverInstruction {
  final int distanceToManeuverMeters;
  final ManeuverType maneuverType;
  final String instructionTitle;
  final String trailName;
  final String surfaceType;
  final double apexElevationM;

  const ManeuverInstruction({
    this.distanceToManeuverMeters = 140,
    this.maneuverType = ManeuverType.hairpinLeft,
    this.instructionTitle = 'Hairpin Left',
    this.trailName = 'Schauinsland Ridge',
    this.surfaceType = 'Compact Gravel',
    this.apexElevationM = 2191.0,
  });

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
    }
  }
}
