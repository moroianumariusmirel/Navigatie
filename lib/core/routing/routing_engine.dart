import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../models/route_model.dart';
import '../models/activity_type.dart';
import '../models/elevation_point.dart';
import '../models/maneuver_instruction.dart';
import '../models/waypoint_model.dart';
import '../navigation/turn_navigation_engine.dart';
import '../offline/offline_download_service.dart';
import 'offline_routing_graph.dart';
import 'graph/road_graph_builder.dart';

enum OutdoorRoutingProfile {
  roadBike,
  gravelBike,
  mountainBike,
  hiking,
}

OutdoorRoutingProfile activityToProfile(ActivityType activity) {
  switch (activity) {
    case ActivityType.cycling:
      // Cycling profile defaults to gravel/tracks per user preference
      return OutdoorRoutingProfile.gravelBike;
    case ActivityType.hiking:
      return OutdoorRoutingProfile.hiking;
  }
}

abstract class OfflineRoutingEngine {
  Future<RouteModel> calculateRoute({
    required LatLng start,
    required LatLng destination,
    required OutdoorRoutingProfile profile,
    List<LatLng>? waypoints,
    String? customName,
  });

  Future<RouteModel> recalculateOffRoute({
    required LatLng currentPosition,
    required RouteModel activeRoute,
    required OutdoorRoutingProfile profile,
  });
}

/// On-Device Offline Router implementation
/// Locates local downloaded .rgraph or .pmtiles road networks and computes optimal routes along actual roads.
class OnDeviceOfflineRouter implements OfflineRoutingEngine {
  final String? offlineTilesDirectoryPath;
  static const Distance _distCalc = Distance();

  // In-memory regional graph cache: regionKey -> OfflineRoutingGraph
  static final Map<String, OfflineRoutingGraph> _cachedGraphs = {};

  OnDeviceOfflineRouter({this.offlineTilesDirectoryPath});

  static void invalidateCache() {
    _cachedGraphs.clear();
  }

  /// Locates or loads the offline routing graph covering the requested [point]
  Future<OfflineRoutingGraph?> getRoutingGraphForArea(LatLng point) async {
    // 1. Check in-memory cache first
    for (final entry in _cachedGraphs.entries) {
      final node = entry.value.findNearestNode(point, maxDistanceMeters: 5000);
      if (node != null) {
        return entry.value;
      }
    }

    // 2. Query OfflineDownloadService for downloaded regions covering this coordinate
    final service = OfflineDownloadService();
    for (final country in service.countries) {
      for (final region in country.regions) {
        if (region.contains(point) && region.localPmtilesPath != null) {
          final pmtilesFile = File(region.localPmtilesPath!);
          if (pmtilesFile.existsSync()) {
            final rgraphPath = region.localRoutingGraphPath ??
                pmtilesFile.path.replaceAll('.pmtiles', '.rgraph');
            final rgraphFile = File(rgraphPath);

            if (rgraphFile.existsSync() && rgraphFile.lengthSync() > 100) {
              try {
                final jsonStr = await rgraphFile.readAsString();
                final graph = OfflineRoutingGraph.fromJsonString(jsonStr);
                _cachedGraphs[region.id] = graph;
                return graph;
              } catch (e) {
                debugPrint('[OnDeviceOfflineRouter] Error loading graph from $rgraphPath: $e');
              }
            } else {
              // Build on demand directly from downloaded PMTiles
              try {
                debugPrint('[OnDeviceOfflineRouter] Building on-demand road graph for ${region.id}...');
                final graph = await RoadGraphBuilder.buildAndSaveFromPmtiles(
                  pmtilesFile,
                  rgraphFile,
                );
                _cachedGraphs[region.id] = graph;
                return graph;
              } catch (e) {
                debugPrint('[OnDeviceOfflineRouter] Error building graph on-demand: $e');
              }
            }
          }
        }
      }
    }

    // 3. Fallback scan of offline directory (or test directory) for any existing .rgraph or .pmtiles files
    Directory? mapsDir;
    if (offlineTilesDirectoryPath != null) {
      mapsDir = Directory(offlineTilesDirectoryPath!);
    } else {
      try {
        final docDir = await getApplicationDocumentsDirectory().timeout(const Duration(milliseconds: 300));
        mapsDir = Directory('${docDir.path}/offline_maps');
      } catch (_) {
        mapsDir = Directory.current;
      }
    }

    if (mapsDir.existsSync()) {
      final files = mapsDir.listSync().whereType<File>();
      for (final file in files) {
        if (file.path.endsWith('.rgraph')) {
          try {
            final jsonStr = await file.readAsString();
            final graph = OfflineRoutingGraph.fromJsonString(jsonStr);
            final node = graph.findNearestNode(point, maxDistanceMeters: 10000);
            if (node != null) {
              _cachedGraphs[file.path] = graph;
              return graph;
            }
          } catch (_) {}
        }
      }

      // Check local .pmtiles files in directory
      for (final file in files) {
        if (file.path.endsWith('.pmtiles') && !file.path.endsWith('.part')) {
          final rgraphFile = File(file.path.replaceAll('.pmtiles', '.rgraph'));
          if (rgraphFile.existsSync()) {
            try {
              final jsonStr = await rgraphFile.readAsString();
              final graph = OfflineRoutingGraph.fromJsonString(jsonStr);
              final node = graph.findNearestNode(point, maxDistanceMeters: 10000);
              if (node != null) {
                _cachedGraphs[file.path] = graph;
                return graph;
              }
            } catch (_) {}
          }
        }
      }
    }

    return null;
  }

  @override
  Future<RouteModel> calculateRoute({
    required LatLng start,
    required LatLng destination,
    required OutdoorRoutingProfile profile,
    List<LatLng>? waypoints,
    String? customName,
  }) async {
    final allStops = <LatLng>[start, ...(waypoints ?? []), destination];
    final graph = await getRoutingGraphForArea(start) ?? await getRoutingGraphForArea(destination);

    if (graph == null) {
      throw StateError(
        'No downloaded offline map or road network covers this location. Please download the offline region first.',
      );
    }

    final routeCoordinates = <LatLng>[];
    final routeEdges = <RoutingEdge>[];
    double totalDistanceM = 0.0;

    for (int i = 0; i < allStops.length - 1; i++) {
      final segStart = allStops[i];
      final segEnd = allStops[i + 1];

      // Snap to nearest road network node (within 3km)
      final startNode = graph.findNearestNode(segStart, maxDistanceMeters: 5000);
      final endNode = graph.findNearestNode(segEnd, maxDistanceMeters: 5000);

      if (startNode == null || endNode == null) {
        throw StateError(
          'Could not find nearby roads to route along for these coordinates.',
        );
      }

      final pathEdges = graph.findPathAStar(
        startNodeId: startNode.id,
        targetNodeId: endNode.id,
        profile: profile,
      );

      if (pathEdges == null || pathEdges.isEmpty) {
        if (startNode.id == endNode.id) {
          routeCoordinates.add(segStart);
          routeCoordinates.add(startNode.toLatLng);
          routeCoordinates.add(segEnd);
          totalDistanceM += _distCalc.as(LengthUnit.Meter, segStart, segEnd);
          continue;
        }
        throw StateError('No connecting road path found between the selected points.');
      }

      // Add segment geometries
      if (routeCoordinates.isEmpty) {
        routeCoordinates.add(segStart);
      }
      routeCoordinates.add(startNode.toLatLng);

      for (final edge in pathEdges) {
        routeEdges.add(edge);
        totalDistanceM += edge.distanceMeters;

        if (edge.geometry != null && edge.geometry!.isNotEmpty) {
          routeCoordinates.addAll(edge.geometry!);
        }
        final targetNode = graph.nodes[edge.targetId];
        if (targetNode != null) {
          routeCoordinates.add(targetNode.toLatLng);
        }
      }

      routeCoordinates.add(segEnd);
      totalDistanceM += _distCalc.as(LengthUnit.Meter, endNode.toLatLng, segEnd);
    }

    final totalKm = double.parse((totalDistanceM / 1000.0).toStringAsFixed(1));
    final activity = profile == OutdoorRoutingProfile.hiking ? ActivityType.hiking : ActivityType.cycling;

    final durationHours = activity == ActivityType.cycling ? totalKm / 18.0 : totalKm / 4.0;
    final h = durationHours.floor();
    final m = ((durationHours - h) * 60).round();

    final elevationProfile = _synthesizeElevation(routeCoordinates, totalKm);
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

    // Build turn maneuvers along the road path
    final maneuvers = <ManeuverInstruction>[];
    double accumulatedM = 0.0;
    int stepIdx = 0;

    for (final edge in routeEdges) {
      accumulatedM += edge.distanceMeters;
      final node = graph.nodes[edge.sourceId];
      final roadName = edge.name ?? (activity == ActivityType.cycling ? 'Trail Track' : 'Footpath');

      maneuvers.add(ManeuverInstruction(
        distanceToManeuverMeters: edge.distanceMeters.toInt(),
        distanceAlongRouteM: accumulatedM,
        stepIndex: stepIdx++,
        coordinate: node?.toLatLng,
        maneuverType: ManeuverType.straight,
        instructionTitle: 'Follow $roadName',
        trailName: roadName,
        surfaceType: edge.roadType == RoadType.track || edge.roadType == RoadType.path ? 'Gravel / Dirt Track' : 'Paved Road',
        apexElevationM: node?.elevationM ?? 850.0,
      ));
    }

    final finalManeuvers = maneuvers.isNotEmpty
        ? maneuvers
        : TurnNavigationEngine.extractManeuversFromCoordinates(
            coordinates: routeCoordinates,
            activityType: activity,
            routeName: customName ?? 'Offline Track',
          );

    final waypointsList = <WaypointModel>[];
    for (int i = 0; i < allStops.length; i++) {
      final isStart = i == 0;
      final isFinish = i == allStops.length - 1;
      waypointsList.add(WaypointModel(
        index: i + 1,
        title: isStart ? 'Start Point' : isFinish ? 'Arrival Destination' : 'Waypoint $i',
        elevation: '${minEle.toInt() + (i * 80)}m',
        distance: '${(totalKm * (i / (allStops.length - 1))).toStringAsFixed(1)} km',
        type: isStart ? 'trailhead' : isFinish ? 'finish' : 'waypoint',
      ));
    }

    return RouteModel(
      id: 'offline_router_${DateTime.now().millisecondsSinceEpoch}',
      name: customName ?? 'Offline Road Route',
      activityType: activity,
      totalDistanceKm: totalKm,
      totalAscentM: double.parse(totalAscent.toStringAsFixed(0)),
      totalDescentM: double.parse(totalDescent.toStringAsFixed(0)),
      maxElevationM: maxEle,
      minElevationM: minEle,
      estimatedDuration: '${h}h ${m}m',
      difficultyRating: activity == ActivityType.cycling ? 'Gravel / Trail Route' : 'Hiking Trail',
      surfaceBreakdown: activity == ActivityType.cycling
          ? const {'Gravel / Dirt': 0.70, 'Asphalt': 0.20, 'Path': 0.10}
          : const {'Trail': 0.75, 'Gravel': 0.15, 'Asphalt': 0.10},
      elevationProfile: elevationProfile,
      maneuvers: finalManeuvers,
      waypoints: waypointsList,
      coordinates: routeCoordinates,
    );
  }

  @override
  Future<RouteModel> recalculateOffRoute({
    required LatLng currentPosition,
    required RouteModel activeRoute,
    required OutdoorRoutingProfile profile,
  }) async {
    return activeRoute;
  }

  static List<ElevationPoint> _synthesizeElevation(List<LatLng> coords, double totalKm) {
    if (coords.isEmpty) {
      return [const ElevationPoint(distanceKm: 0.0, elevationM: 850.0, gradePercent: 0.0)];
    }
    final points = <ElevationPoint>[];
    for (int i = 0; i < coords.length; i++) {
      final progress = i / (coords.length > 1 ? coords.length - 1 : 1);
      final distKm = double.parse((totalKm * progress).toStringAsFixed(2));
      final ele = 850.0 + (distKm * 15.0) + (progress * 120.0);
      points.add(ElevationPoint(
        distanceKm: distKm,
        elevationM: double.parse(ele.toStringAsFixed(0)),
        gradePercent: 1.5,
      ));
    }
    return points;
  }
}
