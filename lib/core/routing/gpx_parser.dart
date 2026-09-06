import 'dart:convert';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';
import '../models/route_model.dart';
import '../models/elevation_point.dart';
import '../models/maneuver_instruction.dart';
import '../models/activity_type.dart';
import '../models/waypoint_model.dart';

class GpxParser {
  static const Distance _distance = Distance();

  /// Parses GPX 1.0 or 1.1 XML string into a RouteModel
  static RouteModel parseGpx(
    String gpxContent, {
    ActivityType defaultActivity = ActivityType.cycling,
    String? fallbackName,
  }) {
    final document = XmlDocument.parse(gpxContent);
    final gpxElement = document.rootElement;

    // 1. Extract Route Name
    String routeName = fallbackName ?? 'Imported GPX Trail';
    final metadataName = gpxElement.findElements('metadata').firstOrNull?.findElements('name').firstOrNull?.innerText;
    final trkName = gpxElement.findAllElements('trk').firstOrNull?.findElements('name').firstOrNull?.innerText;
    final rteName = gpxElement.findAllElements('rte').firstOrNull?.findElements('name').firstOrNull?.innerText;
    if (metadataName != null && metadataName.trim().isNotEmpty) {
      routeName = metadataName.trim();
    } else if (trkName != null && trkName.trim().isNotEmpty) {
      routeName = trkName.trim();
    } else if (rteName != null && rteName.trim().isNotEmpty) {
      routeName = rteName.trim();
    }

    // 2. Extract Raw Coordinates & Elevations
    final rawTrackpoints = <_RawPoint>[];
    final trkpts = gpxElement.findAllElements('trkpt');
    final rtepts = gpxElement.findAllElements('rtept');

    final pointsElements = trkpts.isNotEmpty ? trkpts : rtepts;
    for (final node in pointsElements) {
      final latStr = node.getAttribute('lat');
      final lonStr = node.getAttribute('lon');
      if (latStr == null || lonStr == null) continue;

      final lat = double.tryParse(latStr);
      final lon = double.tryParse(lonStr);
      if (lat == null || lon == null) continue;

      final eleNode = node.findElements('ele').firstOrNull;
      final ele = eleNode != null ? (double.tryParse(eleNode.innerText) ?? 0.0) : 0.0;

      rawTrackpoints.add(_RawPoint(LatLng(lat, lon), ele));
    }

    // 3. Extract Waypoints
    final waypoints = <WaypointModel>[];
    int wptIndex = 1;
    for (final wptNode in gpxElement.findAllElements('wpt')) {
      final lat = double.tryParse(wptNode.getAttribute('lat') ?? '');
      final lon = double.tryParse(wptNode.getAttribute('lon') ?? '');
      if (lat == null || lon == null) continue;

      final name = wptNode.findElements('name').firstOrNull?.innerText ?? 'Point $wptIndex';
      final ele = wptNode.findElements('ele').firstOrNull?.innerText ?? '0';
      final desc = wptNode.findElements('desc').firstOrNull?.innerText;

      waypoints.add(WaypointModel(
        index: wptIndex++,
        title: name,
        elevation: '${double.tryParse(ele)?.toInt() ?? 0}m',
        distance: '-- km',
        description: desc,
      ));
    }

    // Fallback if no trackpoints found in GPX
    if (rawTrackpoints.isEmpty) {
      return defaultActivity == ActivityType.cycling
          ? RouteModel.sampleSchauinsland().copyWith(name: routeName)
          : RouteModel.sampleFeldbergHike().copyWith(name: routeName);
    }

    // 4. Compute Distance, Ascent, Descent, Elevation Profile
    double cumulativeDistanceM = 0.0;
    double totalAscent = 0.0;
    double totalDescent = 0.0;
    double minEle = rawTrackpoints.first.elevation;
    double maxEle = rawTrackpoints.first.elevation;

    final elevationProfile = <ElevationPoint>[];
    final coordinates = <LatLng>[rawTrackpoints.first.latLng];

    // Add first profile point
    elevationProfile.add(ElevationPoint(
      distanceKm: 0.0,
      elevationM: rawTrackpoints.first.elevation,
      gradePercent: 0.0,
    ));

    // Downsample interval for profile points (~20 profile points)
    final int sampleInterval = math.max(1, (rawTrackpoints.length / 20).floor());

    for (int i = 1; i < rawTrackpoints.length; i++) {
      final prev = rawTrackpoints[i - 1];
      final curr = rawTrackpoints[i];
      coordinates.add(curr.latLng);

      final segDistM = _distance.as(LengthUnit.Meter, prev.latLng, curr.latLng);
      cumulativeDistanceM += segDistM;

      final deltaEle = curr.elevation - prev.elevation;
      if (deltaEle > 0) {
        totalAscent += deltaEle;
      } else {
        totalDescent += deltaEle.abs();
      }

      if (curr.elevation > maxEle) maxEle = curr.elevation;
      if (curr.elevation < minEle) minEle = curr.elevation;

      if (i % sampleInterval == 0 || i == rawTrackpoints.length - 1) {
        final double distKm = cumulativeDistanceM / 1000.0;
        final double grade = segDistM > 0 ? (deltaEle / segDistM) * 100.0 : 0.0;
        elevationProfile.add(ElevationPoint(
          distanceKm: double.parse(distKm.toStringAsFixed(1)),
          elevationM: curr.elevation,
          gradePercent: double.parse(grade.toStringAsFixed(1)),
        ));
      }
    }

    final double totalDistKm = double.parse((cumulativeDistanceM / 1000.0).toStringAsFixed(1));

    // Calculate Estimated Duration based on activity
    String duration;
    if (defaultActivity == ActivityType.cycling) {
      final hours = totalDistKm / 20.0 + (totalAscent / 600.0);
      final h = hours.floor();
      final m = ((hours - h) * 60).round();
      duration = '${h}h ${m}m';
    } else {
      // Tobler's Hiking function approximation: ~4 km/h flat + 1h per 350m ascent
      final hours = totalDistKm / 4.0 + (totalAscent / 350.0);
      final h = hours.floor();
      final m = ((hours - h) * 60).round();
      duration = '${h}h ${m}m';
    }

    // Build synthesized waypoints if none existed
    final finalWaypoints = waypoints.isNotEmpty
        ? waypoints
        : [
            WaypointModel(
              index: 1,
              title: 'Start: ${rawTrackpoints.first.latLng.latitude.toStringAsFixed(3)}, ${rawTrackpoints.first.latLng.longitude.toStringAsFixed(3)}',
              elevation: '${rawTrackpoints.first.elevation.toInt()}m',
              distance: '0.0 km',
              type: 'trailhead',
            ),
            WaypointModel(
              index: 2,
              title: 'Apex Elevation Summit',
              elevation: '${maxEle.toInt()}m',
              distance: '${(totalDistKm * 0.65).toStringAsFixed(1)} km',
              isApex: true,
              type: 'summit',
            ),
            WaypointModel(
              index: 3,
              title: 'Finish Destination',
              elevation: '${rawTrackpoints.last.elevation.toInt()}m',
              distance: '$totalDistKm km',
              type: 'finish',
            ),
          ];

    return RouteModel(
      id: 'gpx_${DateTime.now().millisecondsSinceEpoch}',
      name: routeName,
      activityType: defaultActivity,
      totalDistanceKm: totalDistKm,
      totalAscentM: double.parse(totalAscent.toStringAsFixed(0)),
      totalDescentM: double.parse(totalDescent.toStringAsFixed(0)),
      maxElevationM: double.parse(maxEle.toStringAsFixed(0)),
      minElevationM: double.parse(minEle.toStringAsFixed(0)),
      estimatedDuration: duration,
      difficultyRating: defaultActivity == ActivityType.cycling
          ? 'S1 • Custom GPX Track'
          : 'T2 • Custom Alpine Hike',
      surfaceBreakdown: defaultActivity == ActivityType.cycling
          ? const {
              'Compact Gravel': 0.55,
              'Paved Road': 0.30,
              'Singletrack': 0.15,
            }
          : const {
              'Alpine Trail': 0.60,
              'Forest Path': 0.25,
              'Rocky Path': 0.15,
            },
      elevationProfile: elevationProfile,
      maneuvers: [
        ManeuverInstruction(
          distanceToManeuverMeters: 120,
          maneuverType: ManeuverType.straight,
          instructionTitle: 'Follow Imported Track',
          trailName: routeName,
          surfaceType: 'Trail',
          apexElevationM: maxEle,
        ),
      ],
      waypoints: finalWaypoints,
      coordinates: coordinates,
    );
  }

  /// Parses GeoJSON LineString or FeatureCollection format
  static RouteModel parseGeoJson(
    String geoJsonContent, {
    ActivityType defaultActivity = ActivityType.cycling,
    String? fallbackName,
  }) {
    final Map<String, dynamic> data = jsonDecode(geoJsonContent);
    String routeName = fallbackName ?? 'GeoJSON Trail';

    List coordinatesList = [];
    if (data['type'] == 'FeatureCollection') {
      final features = data['features'] as List;
      for (final f in features) {
        final geom = f['geometry'];
        if (geom != null && geom['type'] == 'LineString') {
          coordinatesList = geom['coordinates'] as List;
          if (f['properties'] != null && f['properties']['name'] != null) {
            routeName = f['properties']['name'].toString();
          }
          break;
        }
      }
    } else if (data['type'] == 'Feature' && data['geometry'] != null) {
      coordinatesList = data['geometry']['coordinates'] as List;
    } else if (data['type'] == 'LineString') {
      coordinatesList = data['coordinates'] as List;
    }

    final rawPoints = <_RawPoint>[];
    for (final coord in coordinatesList) {
      if (coord is List && coord.length >= 2) {
        final lon = (coord[0] as num).toDouble();
        final lat = (coord[1] as num).toDouble();
        final ele = coord.length >= 3 ? (coord[2] as num).toDouble() : 500.0;
        rawPoints.add(_RawPoint(LatLng(lat, lon), ele));
      }
    }

    // Convert raw points into GPX-like format
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<gpx version="1.1"><metadata><name>$routeName</name></metadata><trk><trkseg>');
    for (final p in rawPoints) {
      buffer.writeln('<trkpt lat="${p.latLng.latitude}" lon="${p.latLng.longitude}"><ele>${p.elevation}</ele></trkpt>');
    }
    buffer.writeln('</trkseg></trk></gpx>');

    return parseGpx(buffer.toString(), defaultActivity: defaultActivity, fallbackName: routeName);
  }
}

class _RawPoint {
  final LatLng latLng;
  final double elevation;

  const _RawPoint(this.latLng, this.elevation);
}
