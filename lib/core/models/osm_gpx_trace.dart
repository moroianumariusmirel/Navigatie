import 'package:latlong2/latlong.dart';
import 'activity_type.dart';
import 'route_model.dart';
import 'elevation_point.dart';
import 'waypoint_model.dart';
import 'maneuver_instruction.dart';

class OsmGpxTrace {
  final String id;
  final String name;
  final String description;
  final ActivityType activityType;
  final double distanceKm;
  final double ascentM;
  final double descentM;
  final double maxElevationM;
  final double minElevationM;
  final String difficulty;
  final String uploader;
  final String uploadedAt;
  final int trackpointCount;
  final List<String> tags;
  final List<LatLng> coordinates;
  final bool isDownloaded;

  const OsmGpxTrace({
    required this.id,
    required this.name,
    required this.description,
    required this.activityType,
    required this.distanceKm,
    required this.ascentM,
    required this.descentM,
    required this.maxElevationM,
    required this.minElevationM,
    required this.difficulty,
    required this.uploader,
    required this.uploadedAt,
    required this.trackpointCount,
    required this.tags,
    required this.coordinates,
    this.isDownloaded = false,
  });

  OsmGpxTrace copyWith({
    bool? isDownloaded,
  }) {
    return OsmGpxTrace(
      id: id,
      name: name,
      description: description,
      activityType: activityType,
      distanceKm: distanceKm,
      ascentM: ascentM,
      descentM: descentM,
      maxElevationM: maxElevationM,
      minElevationM: minElevationM,
      difficulty: difficulty,
      uploader: uploader,
      uploadedAt: uploadedAt,
      trackpointCount: trackpointCount,
      tags: tags,
      coordinates: coordinates,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }

  RouteModel toRouteModel() {
    // Generate synthetic elevation profile across distance
    final profile = <ElevationPoint>[];
    const steps = 10;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final dist = distanceKm * t;
      // Parabolic elevation peak around 65% of the route
      final peakFactor = (1.0 - (t - 0.65).abs() * 2).clamp(0.0, 1.0);
      final ele = minElevationM + (maxElevationM - minElevationM) * peakFactor;
      final grade = i < steps ? (t < 0.65 ? 8.5 : -7.0) : 0.0;
      profile.add(ElevationPoint(
        distanceKm: double.parse(dist.toStringAsFixed(1)),
        elevationM: double.parse(ele.toStringAsFixed(0)),
        gradePercent: grade,
      ));
    }

    final duration = activityType == ActivityType.cycling
        ? '${(distanceKm / 20.0).floor()}h ${(((distanceKm / 20.0) % 1) * 60).round()}m'
        : '${(distanceKm / 3.8 + ascentM / 350.0).floor()}h ${((((distanceKm / 3.8 + ascentM / 350.0)) % 1) * 60).round()}m';

    return RouteModel(
      id: id,
      name: name,
      activityType: activityType,
      totalDistanceKm: distanceKm,
      totalAscentM: ascentM,
      totalDescentM: descentM,
      maxElevationM: maxElevationM,
      minElevationM: minElevationM,
      estimatedDuration: duration,
      difficultyRating: difficulty,
      surfaceBreakdown: activityType == ActivityType.cycling
          ? const {
              'Compact Gravel': 0.60,
              'Singletrack': 0.30,
              'Paved Road': 0.10,
            }
          : const {
              'Alpine Path': 0.55,
              'Forest Trail': 0.30,
              'Rocky Scramble': 0.15,
            },
      elevationProfile: profile,
      maneuvers: [
        ManeuverInstruction(
          distanceToManeuverMeters: 100,
          maneuverType: ManeuverType.straight,
          instructionTitle: 'Follow $name',
          trailName: name,
          surfaceType: activityType == ActivityType.cycling ? 'Gravel' : 'Trail',
          apexElevationM: maxElevationM,
        ),
      ],
      waypoints: [
        if (coordinates.isNotEmpty)
          WaypointModel(
            index: 1,
            title: 'Start: ${name.split(' ').first} Trailhead',
            elevation: '${minElevationM.toInt()}m',
            distance: '0.0 km',
            type: 'trailhead',
          ),
        WaypointModel(
          index: 2,
          title: 'Summit Apex Ridge',
          elevation: '${maxElevationM.toInt()}m',
          distance: '${(distanceKm * 0.65).toStringAsFixed(1)} km',
          isApex: true,
          type: 'summit',
        ),
        if (coordinates.isNotEmpty)
          WaypointModel(
            index: 3,
            title: 'Finish Destination',
            elevation: '${minElevationM.toInt()}m',
            distance: '$distanceKm km',
            type: 'finish',
          ),
      ],
      coordinates: coordinates,
    );
  }
}
