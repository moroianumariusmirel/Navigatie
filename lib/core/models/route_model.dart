import 'package:latlong2/latlong.dart';
import 'elevation_point.dart';
import 'maneuver_instruction.dart';
import 'activity_type.dart';
import 'waypoint_model.dart';

class RouteModel {
  final String id;
  final String name;
  final ActivityType activityType;
  final double totalDistanceKm;
  final double totalAscentM;
  final double totalDescentM;
  final double maxElevationM;
  final double minElevationM;
  final String estimatedDuration;
  final String difficultyRating;
  final Map<String, double> surfaceBreakdown;
  final List<ElevationPoint> elevationProfile;
  final List<ManeuverInstruction> maneuvers;
  final List<WaypointModel> waypoints;
  final List<LatLng> coordinates;

  const RouteModel({
    required this.id,
    required this.name,
    this.activityType = ActivityType.cycling,
    required this.totalDistanceKm,
    required this.totalAscentM,
    required this.totalDescentM,
    required this.maxElevationM,
    required this.minElevationM,
    required this.estimatedDuration,
    required this.difficultyRating,
    required this.surfaceBreakdown,
    required this.elevationProfile,
    required this.maneuvers,
    this.waypoints = const [],
    this.coordinates = const [],
  });

  RouteModel copyWith({
    String? id,
    String? name,
    ActivityType? activityType,
    double? totalDistanceKm,
    double? totalAscentM,
    double? totalDescentM,
    double? maxElevationM,
    double? minElevationM,
    String? estimatedDuration,
    String? difficultyRating,
    Map<String, double>? surfaceBreakdown,
    List<ElevationPoint>? elevationProfile,
    List<ManeuverInstruction>? maneuvers,
    List<WaypointModel>? waypoints,
    List<LatLng>? coordinates,
  }) {
    return RouteModel(
      id: id ?? this.id,
      name: name ?? this.name,
      activityType: activityType ?? this.activityType,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      totalAscentM: totalAscentM ?? this.totalAscentM,
      totalDescentM: totalDescentM ?? this.totalDescentM,
      maxElevationM: maxElevationM ?? this.maxElevationM,
      minElevationM: minElevationM ?? this.minElevationM,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      difficultyRating: difficultyRating ?? this.difficultyRating,
      surfaceBreakdown: surfaceBreakdown ?? this.surfaceBreakdown,
      elevationProfile: elevationProfile ?? this.elevationProfile,
      maneuvers: maneuvers ?? this.maneuvers,
      waypoints: waypoints ?? this.waypoints,
      coordinates: coordinates ?? this.coordinates,
    );
  }

  /// Sample high-alpine gravel cycling route matching the Stitch 3D Cockpit
  static RouteModel sampleSchauinsland() {
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
      activityType: ActivityType.cycling,
      totalDistanceKm: 42.5,
      totalAscentM: 1420.0,
      totalDescentM: 1270.0,
      maxElevationM: 2191.0,
      minElevationM: 1250.0,
      estimatedDuration: '2h 18m',
      difficultyRating: 'S1 • Moderate Singletrack',
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
      waypoints: const [
        WaypointModel(
          index: 1,
          title: 'Start: Kirchzarten Valley Trailhead',
          elevation: '1,250m',
          distance: '0.0 km',
          type: 'trailhead',
        ),
        WaypointModel(
          index: 2,
          title: 'Gießhübel Alpine Refuel Station',
          elevation: '1,680m',
          distance: '18.5 km',
          type: 'water',
        ),
        WaypointModel(
          index: 3,
          title: 'Schauinsland Ridge (Apex)',
          elevation: '2,191m',
          distance: '35.0 km',
          isApex: true,
          type: 'summit',
        ),
        WaypointModel(
          index: 4,
          title: 'Finish: Hinterzarten Lodge',
          elevation: '1,400m',
          distance: '42.5 km',
          type: 'finish',
        ),
      ],
      coordinates: const [
        LatLng(47.965, 7.952), // Kirchzarten
        LatLng(47.952, 7.942),
        LatLng(47.940, 7.925), // Kappel
        LatLng(47.930, 7.915),
        LatLng(47.921, 7.904), // Bohrer
        LatLng(47.912, 7.898), // Schauinsland Ascent
        LatLng(47.908, 7.895), // Apex Summit 2191m
        LatLng(47.895, 7.905), // Haldenköpfle
        LatLng(47.891, 7.935), // Notschrei Pass
        LatLng(47.898, 7.980), // Muggenbrunn
        LatLng(47.906, 8.040), // Bärental
        LatLng(47.910, 8.090), // Hinterzarten
      ],
    );
  }

  /// Sample rugged alpine hiking route
  static RouteModel sampleFeldbergHike() {
    final profile = <ElevationPoint>[
      const ElevationPoint(distanceKm: 0.0, elevationM: 975, gradePercent: 1.5),
      const ElevationPoint(distanceKm: 2.5, elevationM: 1020, gradePercent: 3.8),
      const ElevationPoint(distanceKm: 5.0, elevationM: 1180, gradePercent: 8.5),
      const ElevationPoint(distanceKm: 8.2, elevationM: 1340, gradePercent: 12.0),
      const ElevationPoint(distanceKm: 11.5, elevationM: 1493, gradePercent: 15.4), // APEX: Feldberg Summit
      const ElevationPoint(distanceKm: 14.0, elevationM: 1380, gradePercent: -9.2),
      const ElevationPoint(distanceKm: 18.2, elevationM: 1100, gradePercent: -7.0),
    ];

    return RouteModel(
      id: 'feldberg_alpine_hike_18',
      name: 'Feldberg Cirque & Alpine Ridge Trek',
      activityType: ActivityType.hiking,
      totalDistanceKm: 18.2,
      totalAscentM: 980.0,
      totalDescentM: 855.0,
      maxElevationM: 1493.0,
      minElevationM: 975.0,
      estimatedDuration: '5h 15m',
      difficultyRating: 'T2 • Mountain Trail (Rocky)',
      surfaceBreakdown: const {
        'Forest Trail / Dirt': 0.55,
        'Alpine Singletrack': 0.30,
        'Rocky Scramble / Scree': 0.15,
      },
      elevationProfile: profile,
      maneuvers: const [
        ManeuverInstruction(
          distanceToManeuverMeters: 85,
          maneuverType: ManeuverType.slightRight,
          instructionTitle: 'Bear Right onto Alpine Path',
          trailName: 'Feldberg Steig',
          surfaceType: 'Rocky Scramble',
          apexElevationM: 1493.0,
        ),
      ],
      waypoints: const [
        WaypointModel(
          index: 1,
          title: 'Start: Feldsee Glacial Cirque',
          elevation: '975m',
          distance: '0.0 km',
          type: 'trailhead',
        ),
        WaypointModel(
          index: 2,
          title: 'Raimartihof Historical Alpine Hut',
          elevation: '1,020m',
          distance: '2.5 km',
          type: 'hut',
        ),
        WaypointModel(
          index: 3,
          title: 'Feldberg Summit & Tower (Apex)',
          elevation: '1,493m',
          distance: '11.5 km',
          isApex: true,
          type: 'summit',
        ),
        WaypointModel(
          index: 4,
          title: 'St. Wilhelmer Hut Shelter',
          elevation: '1,380m',
          distance: '14.0 km',
          type: 'shelter',
        ),
        WaypointModel(
          index: 5,
          title: 'Finish: Rinken Valley Station',
          elevation: '1,100m',
          distance: '18.2 km',
          type: 'finish',
        ),
      ],
      coordinates: const [
        LatLng(47.871, 8.033), // Feldsee
        LatLng(47.876, 8.026), // Raimartihof
        LatLng(47.879, 8.018), // Grünes Grüble
        LatLng(47.874, 8.003), // Feldberg Summit (Apex)
        LatLng(47.882, 7.994), // St. Wilhelmer Hütte
        LatLng(47.889, 8.012), // Zastler Hütte
        LatLng(47.889, 8.030), // Rinken Valley
      ],
    );
  }
}
