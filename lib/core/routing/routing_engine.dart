import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';
import '../models/activity_type.dart';
import '../models/elevation_point.dart';
import '../models/maneuver_instruction.dart';
import '../models/waypoint_model.dart';
import '../navigation/turn_navigation_engine.dart';
import 'offline_routing_graph.dart';
import 'regional_road_networks.dart';

enum OutdoorRoutingProfile {
  roadBike,
  gravelBike,
  mountainBike,
  hiking,
}

OutdoorRoutingProfile activityToProfile(ActivityType activity) {
  switch (activity) {
    case ActivityType.cycling:
      return OutdoorRoutingProfile.roadBike;
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
/// Snaps tapped coordinates to regional road graphs and computes optimal routes along actual roads.
class OnDeviceOfflineRouter implements OfflineRoutingEngine {
  final String? offlineTilesDirectoryPath;
  static const Distance _distCalc = Distance();

  // In-memory regional graph cache
  static final Map<String, OfflineRoutingGraph> _cachedGraphs = {};

  OnDeviceOfflineRouter({this.offlineTilesDirectoryPath});

  /// Loads the most appropriate regional road network covering the requested area
  OfflineRoutingGraph getRoutingGraphForArea(LatLng point) {
    // Check Romania Muntenia & Danube Delta (Lat: ~43.6 to 45.6, Lon: ~24.5 to 29.8)
    if (point.latitude >= 43.5 &&
        point.latitude <= 45.6 &&
        point.longitude >= 24.5 &&
        point.longitude <= 30.0) {
      return _cachedGraphs.putIfAbsent(
        'muntenia',
        () => RegionalRoadNetworks.getMunteniaNetwork(),
      );
    }

    // Check Transylvania / Bucegi-Brasov / Carpathians (Lat: ~45.2 to 47.5, Lon: ~22.5 to 26.5)
    if (point.latitude >= 45.0 &&
        point.latitude <= 47.8 &&
        point.longitude >= 22.0 &&
        point.longitude <= 26.5) {
      return _cachedGraphs.putIfAbsent(
        'transylvania',
        () => RegionalRoadNetworks.getTransylvaniaNetwork(),
      );
    }

    // Default to combined Romanian network
    return _cachedGraphs.putIfAbsent('default_romania', () {
      final muntenia = RegionalRoadNetworks.getMunteniaNetwork();
      final transylvania = RegionalRoadNetworks.getTransylvaniaNetwork();

      final combined = OfflineRoutingGraph();
      muntenia.nodes.forEach((k, v) => combined.addNode(v));
      transylvania.nodes.forEach((k, v) => combined.addNode(v));

      muntenia.adjacency.forEach((k, list) {
        for (final edge in list) {
          combined.addEdge(edge);
        }
      });
      transylvania.adjacency.forEach((k, list) {
        for (final edge in list) {
          combined.addEdge(edge);
        }
      });

      // Link Predeal (205) in Muntenia to Predeal (604) in Transylvania to unite regions!
      combined.addEdge(const RoutingEdge(
        sourceId: 205,
        targetId: 604,
        distanceMeters: 50.0,
        roadType: RoadType.primary,
        name: 'DN1 Pasul Predeal (Conexiune Regionala)',
      ));

      return combined;
    });
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
    final graph = getRoutingGraphForArea(start);

    final routeCoordinates = <LatLng>[];
    final routeEdges = <RoutingEdge>[];
    double totalDistanceM = 0.0;

    for (int i = 0; i < allStops.length - 1; i++) {
      final segStart = allStops[i];
      final segEnd = allStops[i + 1];

      // Snap to nearest road network node
      final startNode = graph.findNearestNode(segStart, maxDistanceMeters: 50000);
      final endNode = graph.findNearestNode(segEnd, maxDistanceMeters: 50000);

      if (startNode != null && endNode != null) {
        final pathEdges = graph.findPathAStar(
          startNodeId: startNode.id,
          targetNodeId: endNode.id,
          profile: profile,
        );

        if (pathEdges != null && pathEdges.isNotEmpty) {
          // Connect actual start point to snapped start node
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

          // Connect snapped end node to destination
          routeCoordinates.add(segEnd);
          totalDistanceM += _distCalc.as(LengthUnit.Meter, endNode.toLatLng, segEnd);
        } else {
          // A* returned no path or startNode == endNode
          routeCoordinates.add(segStart);
          if (startNode.toLatLng != segStart) routeCoordinates.add(startNode.toLatLng);
          if (endNode.toLatLng != segEnd) routeCoordinates.add(endNode.toLatLng);
          routeCoordinates.add(segEnd);
          totalDistanceM += _distCalc.as(LengthUnit.Meter, segStart, segEnd);
        }
      } else {
        // Fallback straight segment if way outside coverage
        routeCoordinates.add(segStart);
        routeCoordinates.add(segEnd);
        totalDistanceM += _distCalc.as(LengthUnit.Meter, segStart, segEnd);
      }
    }

    final totalKm = double.parse((totalDistanceM / 1000.0).toStringAsFixed(1));
    final activity = profile == OutdoorRoutingProfile.hiking ? ActivityType.hiking : ActivityType.cycling;

    final durationHours = activity == ActivityType.cycling ? totalKm / 19.5 : totalKm / 4.0;
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

    // Build maneuvers along the road path
    final maneuvers = <ManeuverInstruction>[];
    double accumulatedM = 0.0;
    int stepIdx = 0;

    for (final edge in routeEdges) {
      accumulatedM += edge.distanceMeters;
      final node = graph.nodes[edge.sourceId];
      final roadName = edge.name ?? (activity == ActivityType.cycling ? 'Cycle Route' : 'Trail Path');

      maneuvers.add(ManeuverInstruction(
        distanceToManeuverMeters: edge.distanceMeters.toInt(),
        distanceAlongRouteM: accumulatedM,
        stepIndex: stepIdx++,
        coordinate: node?.toLatLng,
        maneuverType: ManeuverType.straight,
        instructionTitle: 'Follow $roadName',
        trailName: roadName,
        surfaceType: edge.roadType == RoadType.track || edge.roadType == RoadType.path ? 'Gravel / Dirt' : 'Asphalt Road',
        apexElevationM: node?.elevationM ?? 850.0,
      ));
    }

    // Fallback maneuvers if no edges
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
      difficultyRating: activity == ActivityType.cycling ? 'S1 • Offline Road Navigation' : 'T2 • Offline Trail Navigation',
      surfaceBreakdown: activity == ActivityType.cycling
          ? const {'Asphalt': 0.70, 'Gravel': 0.25, 'Path': 0.05}
          : const {'Trail': 0.65, 'Gravel': 0.25, 'Asphalt': 0.10},
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
