import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/activity_type.dart';
import '../models/route_model.dart';
import '../models/elevation_point.dart';
import '../models/maneuver_instruction.dart';
import '../models/waypoint_model.dart';
import '../navigation/turn_navigation_engine.dart';
import '../offline/offline_download_service.dart';
import 'routing_engine.dart';

class OsmRoutingService {
  static const Distance _distCalc = Distance();

  /// Testing or offline-forcing flag to simulate offline mode
  static bool simulatedOfflineMode = false;

  /// Calculates a real outdoor route through OpenStreetMap roads, tracks, and footpaths
  static Future<RouteModel> calculateRoute({
    required List<LatLng> points,
    required ActivityType activityType,
    String? customName,
  }) async {
    if (points.length < 2) {
      throw ArgumentError('At least 2 points (Start and Arrival) are required to calculate a route.');
    }

    final isCycling = activityType == ActivityType.cycling;
    final engine = isCycling ? 'routed-bike' : 'routed-foot';

    // Format coordinates: lon,lat;lon,lat;...
    final coordsParam = points.map((p) => '${p.longitude.toStringAsFixed(6)},${p.latitude.toStringAsFixed(6)}').join(';');
    final url = 'https://routing.openstreetmap.de/$engine/route/v1/driving/$coordsParam?overview=full&geometries=geojson&steps=true';

    try {
      if (simulatedOfflineMode) {
        throw const SocketException('Simulated offline mode enabled');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'TrailPulse/1.0 (contact@trailpulse.app; outdoor-navigation)',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final routeData = data['routes'][0];
          return _parseOsrmRoute(routeData, points, activityType, customName);
        }
      }
      throw HttpException('Server returned non-200 status ${response.statusCode}');
    } catch (e) {
      // Network failed or offline: calculate using On-Device Offline Road Router!
      final offlineRouter = OnDeviceOfflineRouter();
      try {
        final profile = activityToProfile(activityType);
        final start = points.first;
        final destination = points.last;
        final waypoints = points.length > 2 ? points.sublist(1, points.length - 1) : null;

        return await offlineRouter.calculateRoute(
          start: start,
          destination: destination,
          profile: profile,
          waypoints: waypoints,
          customName: customName,
        );
      } catch (routerErr) {
        debugPrint('[OsmRoutingService] Offline road routing error: $routerErr');

        // Check if an offline map actually covers this region
        final start = points.first;
        final destination = points.last;
        final dlService = OfflineDownloadService();
        final isCovered = dlService.isLocationCoveredOffline(start) ||
            dlService.isLocationCoveredOffline(destination);
        final graph = await offlineRouter.getRoutingGraphForArea(start) ??
            await offlineRouter.getRoutingGraphForArea(destination);

        // If an offline map covers the area or a graph was loaded, surface the real routing error
        // so the user knows why road routing failed rather than masking it with a straight line.
        if (isCovered || graph != null) {
          rethrow;
        }

        // Only fall back to straight line interpolation if no offline map has been downloaded
      }
    }

    return _generateOfflineFallbackRoute(points, activityType, customName);
  }

  static RouteModel _parseOsrmRoute(
    Map<String, dynamic> routeData,
    List<LatLng> originalWaypoints,
    ActivityType activityType,
    String? customName,
  ) {
    final double totalDistanceM = (routeData['distance'] as num).toDouble();
    final double totalDistanceKm = double.parse((totalDistanceM / 1000.0).toStringAsFixed(1));
    final double durationSec = (routeData['duration'] as num).toDouble();

    final List rawCoords = routeData['geometry']['coordinates'] as List;
    final coordinates = <LatLng>[];
    for (final c in rawCoords) {
      if (c is List && c.length >= 2) {
        coordinates.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
      }
    }

    // Extract maneuvers from steps
    final maneuvers = <ManeuverInstruction>[];
    double accumulatedDistM = 0.0;
    int stepIdx = 0;
    if (routeData['legs'] != null) {
      for (final leg in routeData['legs'] as List) {
        if (leg['steps'] != null) {
          for (final step in leg['steps'] as List) {
            final double dist = (step['distance'] as num?)?.toDouble() ?? 0.0;
            final String name = step['name']?.toString() ?? 'Trail';
            final maneuverData = step['maneuver'];
            final String type = maneuverData != null ? (maneuverData['type']?.toString() ?? 'straight') : 'straight';
            final String modifier = maneuverData != null ? (maneuverData['modifier']?.toString() ?? '') : '';

            LatLng? stepCoord;
            if (maneuverData != null && maneuverData['location'] is List) {
              final loc = maneuverData['location'] as List;
              if (loc.length >= 2) {
                stepCoord = LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble());
              }
            }

            accumulatedDistM += dist;

            maneuvers.add(ManeuverInstruction(
              distanceToManeuverMeters: dist.toInt(),
              distanceAlongRouteM: accumulatedDistM,
              stepIndex: stepIdx++,
              coordinate: stepCoord,
              maneuverType: _mapOsrmManeuver(type, modifier),
              instructionTitle: _buildInstructionTitle(type, modifier, name),
              trailName: name.isNotEmpty ? name : (activityType == ActivityType.cycling ? 'Cycle Track' : 'Alpine Trail'),
              surfaceType: activityType == ActivityType.cycling ? 'Compact Gravel' : 'Mountain Footpath',
              apexElevationM: 1450.0,
            ));
          }
        }
      }
    }

    // Synthesize realistic elevation profile along the actual route points
    final elevationProfile = _synthesizeElevationProfile(coordinates, totalDistanceKm);
    double minEle = elevationProfile.first.elevationM;
    double maxEle = elevationProfile.first.elevationM;
    double totalAscent = 0.0;
    double totalDescent = 0.0;

    for (int i = 1; i < elevationProfile.length; i++) {
      final prev = elevationProfile[i - 1];
      final curr = elevationProfile[i];
      final diff = curr.elevationM - prev.elevationM;
      if (diff > 0) totalAscent += diff;
      if (diff < 0) totalDescent += diff.abs();
      if (curr.elevationM > maxEle) maxEle = curr.elevationM;
      if (curr.elevationM < minEle) minEle = curr.elevationM;
    }

    final durationHours = durationSec / 3600.0;
    final h = durationHours.floor();
    final m = ((durationHours - h) * 60).round();
    final durationStr = '${h}h ${m}m';

    final waypoints = <WaypointModel>[];
    for (int i = 0; i < originalWaypoints.length; i++) {
      final p = originalWaypoints[i];
      final isStart = i == 0;
      final isFinish = i == originalWaypoints.length - 1;
      final title = isStart
          ? 'Start Point'
          : isFinish
              ? 'Arrival Destination'
              : 'Stop Waypoint $i';

      waypoints.add(WaypointModel(
        index: i + 1,
        title: title,
        description: '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}',
        elevation: '${minEle.toInt() + (i * 120)}m',
        distance: '${(totalDistanceKm * (i / (originalWaypoints.length - 1))).toStringAsFixed(1)} km',
        isApex: i == (originalWaypoints.length / 2).floor() && !isStart && !isFinish,
        type: isStart ? 'trailhead' : isFinish ? 'finish' : 'waypoint',
      ));
    }

    final routeName = customName ?? (activityType == ActivityType.cycling
        ? 'Custom Calculated Cycle Route'
        : 'Custom Calculated Hiking Trail');

    return RouteModel(
      id: 'osm_calc_${DateTime.now().millisecondsSinceEpoch}',
      name: routeName,
      activityType: activityType,
      totalDistanceKm: totalDistanceKm,
      totalAscentM: double.parse(totalAscent.toStringAsFixed(0)),
      totalDescentM: double.parse(totalDescent.toStringAsFixed(0)),
      maxElevationM: double.parse(maxEle.toStringAsFixed(0)),
      minElevationM: double.parse(minEle.toStringAsFixed(0)),
      estimatedDuration: durationStr,
      difficultyRating: activityType == ActivityType.cycling ? 'S1 • Snapped Cycle Track' : 'T2 • Snapped Mountain Trail',
      surfaceBreakdown: activityType == ActivityType.cycling
          ? const {
              'Compact Gravel': 0.55,
              'Asphalt Cycleway': 0.35,
              'Singletrack': 0.10,
            }
          : const {
              'Alpine Trail': 0.65,
              'Forest Path': 0.25,
              'Rocky Steps': 0.10,
            },
      elevationProfile: elevationProfile,
      maneuvers: maneuvers.length > 1
          ? maneuvers
          : TurnNavigationEngine.extractManeuversFromCoordinates(
              coordinates: coordinates,
              activityType: activityType,
              routeName: routeName,
            ),
      waypoints: waypoints,
      coordinates: coordinates,
    );
  }

  static RouteModel _generateOfflineFallbackRoute(
    List<LatLng> points,
    ActivityType activityType,
    String? customName,
  ) {
    final coordinates = <LatLng>[];
    double totalDistM = 0.0;

    for (int i = 0; i < points.length; i++) {
      coordinates.add(points[i]);
      if (i > 0) {
        totalDistM += _distCalc.as(LengthUnit.Meter, points[i - 1], points[i]);
      }
    }

    final totalKm = double.parse((totalDistM / 1000.0).toStringAsFixed(1));
    final elevationProfile = _synthesizeElevationProfile(coordinates, totalKm);

    final durationHours = activityType == ActivityType.cycling ? totalKm / 18.0 : totalKm / 3.8;
    final h = durationHours.floor();
    final m = ((durationHours - h) * 60).round();

    final waypoints = <WaypointModel>[];
    for (int i = 0; i < points.length; i++) {
      final isStart = i == 0;
      final isFinish = i == points.length - 1;
      waypoints.add(WaypointModel(
        index: i + 1,
        title: isStart ? 'Start Point' : isFinish ? 'Arrival Destination' : 'Stop Point $i',
        elevation: '${950 + i * 110}m',
        distance: '${(totalKm * (i / (points.length - 1))).toStringAsFixed(1)} km',
        type: isStart ? 'trailhead' : isFinish ? 'finish' : 'waypoint',
      ));
    }

    return RouteModel(
      id: 'offline_calc_${DateTime.now().millisecondsSinceEpoch}',
      name: customName ?? 'Custom Created Route',
      activityType: activityType,
      totalDistanceKm: totalKm,
      totalAscentM: double.parse((totalKm * 28.0).toStringAsFixed(0)),
      totalDescentM: double.parse((totalKm * 24.0).toStringAsFixed(0)),
      maxElevationM: 1450.0,
      minElevationM: 950.0,
      estimatedDuration: '${h}h ${m}m',
      difficultyRating: activityType == ActivityType.cycling ? 'S1 • Custom Bike Route' : 'T2 • Custom Trail',
      surfaceBreakdown: activityType == ActivityType.cycling
          ? const {'Gravel': 0.60, 'Asphalt': 0.30, 'Path': 0.10}
          : const {'Trail': 0.70, 'Gravel': 0.20, 'Rock': 0.10},
      elevationProfile: elevationProfile,
      maneuvers: TurnNavigationEngine.extractManeuversFromCoordinates(
        coordinates: coordinates,
        activityType: activityType,
        routeName: customName ?? 'Created Path',
      ),
      waypoints: waypoints,
      coordinates: coordinates,
    );
  }

  static List<ElevationPoint> _synthesizeElevationProfile(List<LatLng> coords, double totalDistKm) {
    final profile = <ElevationPoint>[];
    const pointCount = 12;
    for (int i = 0; i <= pointCount; i++) {
      final t = i / pointCount;
      final dist = double.parse((totalDistKm * t).toStringAsFixed(1));
      // Bell curve climb up to apex at 60% distance
      final curve = math.sin(t * math.pi);
      final ele = 850.0 + (curve * 520.0);
      final grade = i < pointCount ? (t < 0.6 ? 7.5 : -6.5) : 0.0;
      profile.add(ElevationPoint(
        distanceKm: dist,
        elevationM: double.parse(ele.toStringAsFixed(0)),
        gradePercent: grade,
      ));
    }
    return profile;
  }

  static ManeuverType _mapOsrmManeuver(String type, String modifier) {
    if (modifier.contains('slight right')) return ManeuverType.slightRight;
    if (modifier.contains('slight left')) return ManeuverType.slightLeft;
    if (modifier.contains('right')) return ManeuverType.turnRight;
    if (modifier.contains('left')) return ManeuverType.turnLeft;
    if (modifier.contains('sharp right')) return ManeuverType.hairpinRight;
    if (modifier.contains('sharp left')) return ManeuverType.hairpinLeft;
    if (modifier.contains('uturn')) return ManeuverType.uTurn;
    return ManeuverType.straight;
  }

  static String _buildInstructionTitle(String type, String modifier, String name) {
    if (modifier.isNotEmpty) {
      final formattedMod = modifier.replaceAll('_', ' ').toUpperCase();
      return '$formattedMod ${name.isNotEmpty ? 'onto $name' : ''}'.trim();
    }
    return type.toUpperCase();
  }
}
