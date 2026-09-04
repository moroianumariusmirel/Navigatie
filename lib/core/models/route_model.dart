import 'elevation_point.dart';
import 'maneuver_instruction.dart';

class RouteModel {
  final String id;
  final String name;
  final double totalDistanceKm;
  final double totalAscentM;
  final double totalDescentM;
  final double maxElevationM;
  final double minElevationM;
  final Map<String, double> surfaceBreakdown;
  final List<ElevationPoint> elevationProfile;
  final List<ManeuverInstruction> maneuvers;

  const RouteModel({
    required this.id,
    required this.name,
    required this.totalDistanceKm,
    required this.totalAscentM,
    required this.totalDescentM,
    required this.maxElevationM,
    required this.minElevationM,
    required this.surfaceBreakdown,
    required this.elevationProfile,
    required this.maneuvers,
  });

  /// Sample high-alpine gravel route matching the Stitch 3D Cockpit
  static RouteModel sampleSchauinsland() {
    // Generate an elevation profile from 1,200m to 2,191m peak over 42.5 km
    final profile = <ElevationPoint>[
      const ElevationPoint(distanceKm: 0.0, elevationM: 1250, gradePercent: 2.1),
      const ElevationPoint(distanceKm: 5.0, elevationM: 1380, gradePercent: 3.2),
      const ElevationPoint(distanceKm: 10.0, elevationM: 1510, gradePercent: 4.5),
      const ElevationPoint(distanceKm: 15.0, elevationM: 1620, gradePercent: 5.8),
      const ElevationPoint(distanceKm: 20.0, elevationM: 1730, gradePercent: 7.2),
      const ElevationPoint(distanceKm: 24.1, elevationM: 1811, gradePercent: 10.8), // CURRENT POSITION
      const ElevationPoint(distanceKm: 28.0, elevationM: 1940, gradePercent: 11.5),
      const ElevationPoint(distanceKm: 32.0, elevationM: 2090, gradePercent: 14.2),
      const ElevationPoint(distanceKm: 35.0, elevationM: 2191, gradePercent: 16.2), // APEX
      const ElevationPoint(distanceKm: 38.0, elevationM: 1850, gradePercent: -8.5),
      const ElevationPoint(distanceKm: 42.5, elevationM: 1400, gradePercent: -6.0),
    ];

    return RouteModel(
      id: 'schauinsland_gravel_42',
      name: 'Schauinsland Alpine Ridge Traverse',
      totalDistanceKm: 42.5,
      totalAscentM: 1420.0,
      totalDescentM: 1270.0,
      maxElevationM: 2191.0,
      minElevationM: 1250.0,
      surfaceBreakdown: const {
        'Compact Gravel': 0.65,
        'Alpine Singletrack': 0.25,
        'Asphalt Transition': 0.10,
      },
      elevationProfile: profile,
      maneuvers: const [
        ManeuverInstruction(
          distanceToManeuverMeters: 140,
          maneuverType: ManeuverType.hairpinLeft,
          instructionTitle: 'Hairpin Left',
          trailName: 'Schauinsland Ridge',
          surfaceType: 'Compact Gravel',
          apexElevationM: 2191.0,
        ),
      ],
    );
  }
}
