import 'dart:convert';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';
import 'routing_engine.dart';

/// Node representing an intersection or milestone in the road/trail network
class RoutingNode {
  final int id;
  final double lat;
  final double lon;
  final double? elevationM;

  const RoutingNode({
    required this.id,
    required this.lat,
    required this.lon,
    this.elevationM,
  });

  LatLng get toLatLng => LatLng(lat, lon);

  Map<String, dynamic> toJson() => {
        'id': id,
        'lat': lat,
        'lon': lon,
        if (elevationM != null) 'ele': elevationM,
      };

  factory RoutingNode.fromJson(Map<String, dynamic> json) {
    return RoutingNode(
      id: (json['id'] as num).toInt(),
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      elevationM: (json['ele'] as num?)?.toDouble(),
    );
  }
}

/// Road/pathway classification in OpenStreetMap
enum RoadType {
  motorway,
  primary,
  secondary,
  tertiary,
  residential,
  track,
  path,
  cycleway,
  footway,
  unknown,
}

/// Directed edge between two nodes representing a road or trail segment
class RoutingEdge {
  final int sourceId;
  final int targetId;
  final double distanceMeters;
  final RoadType roadType;
  final String? name;
  final bool isOneWay;
  final List<LatLng>? geometry; // Intermediate points along curved roads

  const RoutingEdge({
    required this.sourceId,
    required this.targetId,
    required this.distanceMeters,
    this.roadType = RoadType.residential,
    this.name,
    this.isOneWay = false,
    this.geometry,
  });

  /// Cost factor based on activity profile (hiking vs cycling)
  double computeCost(OutdoorRoutingProfile profile) {
    double factor = 1.0;
    switch (profile) {
      case OutdoorRoutingProfile.roadBike:
        switch (roadType) {
          case RoadType.cycleway:
            factor = 0.8;
            break;
          case RoadType.primary:
          case RoadType.secondary:
          case RoadType.tertiary:
          case RoadType.residential:
            factor = 1.0;
            break;
          case RoadType.track:
            factor = 3.5;
            break;
          case RoadType.path:
          case RoadType.footway:
            factor = 5.0; // avoid unpaved footpaths on road bike
            break;
          case RoadType.motorway:
            factor = 100.0; // prohibited
            break;
          default:
            factor = 1.5;
        }
        break;

      case OutdoorRoutingProfile.gravelBike:
      case OutdoorRoutingProfile.mountainBike:
        switch (roadType) {
          case RoadType.cycleway:
          case RoadType.track:
          case RoadType.path:
            factor = 0.8; // prefer trails and tracks
            break;
          case RoadType.residential:
          case RoadType.tertiary:
          case RoadType.secondary:
            factor = 1.0;
            break;
          case RoadType.primary:
            factor = 1.6;
            break;
          case RoadType.motorway:
            factor = 100.0;
            break;
          default:
            factor = 1.0;
        }
        break;

      case OutdoorRoutingProfile.hiking:
        switch (roadType) {
          case RoadType.path:
          case RoadType.footway:
          case RoadType.track:
            factor = 0.7; // strongly prefer outdoor trails
            break;
          case RoadType.cycleway:
          case RoadType.residential:
            factor = 1.1;
            break;
          case RoadType.secondary:
          case RoadType.tertiary:
            factor = 2.0;
            break;
          case RoadType.primary:
          case RoadType.motorway:
            factor = 10.0; // avoid busy paved highways on foot
            break;
          default:
            factor = 1.0;
        }
        break;
    }

    return distanceMeters * factor;
  }

  Map<String, dynamic> toJson() => {
        's': sourceId,
        't': targetId,
        'd': distanceMeters,
        'type': roadType.name,
        if (name != null) 'name': name,
        if (isOneWay) 'ow': true,
        if (geometry != null && geometry!.isNotEmpty)
          'geo': geometry!.map((p) => [p.latitude, p.longitude]).toList(),
      };

  factory RoutingEdge.fromJson(Map<String, dynamic> json) {
    RoadType rType = RoadType.unknown;
    final typeStr = json['type'] as String?;
    if (typeStr != null) {
      for (final val in RoadType.values) {
        if (val.name == typeStr) {
          rType = val;
          break;
        }
      }
    }

    List<LatLng>? geom;
    if (json['geo'] is List) {
      geom = (json['geo'] as List).map((pt) {
        final pair = pt as List;
        return LatLng((pair[0] as num).toDouble(), (pair[1] as num).toDouble());
      }).toList();
    }

    return RoutingEdge(
      sourceId: (json['s'] as num).toInt(),
      targetId: (json['t'] as num).toInt(),
      distanceMeters: (json['d'] as num).toDouble(),
      roadType: rType,
      name: json['name'] as String?,
      isOneWay: json['ow'] == true,
      geometry: geom,
    );
  }
}

/// A spatial road network graph for offline routing
class OfflineRoutingGraph {
  final Map<int, RoutingNode> nodes = {};
  final Map<int, List<RoutingEdge>> adjacency = {};
  static const Distance _distCalc = Distance();

  // Spatial grid index (0.02 deg ~ 2.2km buckets) for fast O(1) nearest-node snapping
  final Map<String, List<int>> _spatialGrid = {};
  static const double _gridSize = 0.02;

  void addNode(RoutingNode node) {
    nodes[node.id] = node;
    final gridKey = _getGridKey(node.lat, node.lon);
    _spatialGrid.putIfAbsent(gridKey, () => []).add(node.id);
  }

  void addEdge(RoutingEdge edge) {
    adjacency.putIfAbsent(edge.sourceId, () => []).add(edge);
    if (!edge.isOneWay) {
      // Add reverse edge
      final reverseGeom = edge.geometry != null ? List<LatLng>.from(edge.geometry!.reversed) : null;
      adjacency.putIfAbsent(edge.targetId, () => []).add(
            RoutingEdge(
              sourceId: edge.targetId,
              targetId: edge.sourceId,
              distanceMeters: edge.distanceMeters,
              roadType: edge.roadType,
              name: edge.name,
              isOneWay: false,
              geometry: reverseGeom,
            ),
          );
    }
  }

  String _getGridKey(double lat, double lon) {
    final x = (lon / _gridSize).floor();
    final y = (lat / _gridSize).floor();
    return '$x:$y';
  }

  /// Snaps a GPS point to the nearest road network node in the graph
  RoutingNode? findNearestNode(LatLng point, {double maxDistanceMeters = 5000}) {
    if (nodes.isEmpty) return null;

    final startX = (point.longitude / _gridSize).floor();
    final startY = (point.latitude / _gridSize).floor();

    RoutingNode? bestNode;
    double bestDist = double.infinity;

    // Search 3x3 surrounding grid cells first
    for (int dx = -2; dx <= 2; dx++) {
      for (int dy = -2; dy <= 2; dy++) {
        final key = '${startX + dx}:${startY + dy}';
        final nodeIds = _spatialGrid[key];
        if (nodeIds != null) {
          for (final id in nodeIds) {
            final node = nodes[id];
            if (node != null) {
              final d = _distCalc.as(LengthUnit.Meter, point, node.toLatLng);
              if (d < bestDist) {
                bestDist = d;
                bestNode = node;
              }
            }
          }
        }
      }
    }

    if (bestNode != null && bestDist <= maxDistanceMeters) {
      return bestNode;
    }

    // Exhaustive fallback if far outside standard grid cells
    for (final node in nodes.values) {
      final d = _distCalc.as(LengthUnit.Meter, point, node.toLatLng);
      if (d < bestDist) {
        bestDist = d;
        bestNode = node;
      }
    }

    return bestDist <= maxDistanceMeters ? bestNode : null;
  }

  /// Finds the optimal path between startNodeId and targetNodeId using A*
  List<RoutingEdge>? findPathAStar({
    required int startNodeId,
    required int targetNodeId,
    required OutdoorRoutingProfile profile,
  }) {
    if (!nodes.containsKey(startNodeId) || !nodes.containsKey(targetNodeId)) {
      return null;
    }

    if (startNodeId == targetNodeId) {
      return [];
    }

    final targetNode = nodes[targetNodeId]!;

    final openSet = <int>{startNodeId};
    final cameFromEdge = <int, RoutingEdge>{};
    final gScore = <int, double>{startNodeId: 0.0};
    final fScore = <int, double>{
      startNodeId: _heuristic(nodes[startNodeId]!, targetNode),
    };

    while (openSet.isNotEmpty) {
      // Find node with minimum fScore
      int current = openSet.first;
      double minF = fScore[current] ?? double.infinity;
      for (final id in openSet) {
        final f = fScore[id] ?? double.infinity;
        if (f < minF) {
          minF = f;
          current = id;
        }
      }

      if (current == targetNodeId) {
        // Reconstruct path
        final path = <RoutingEdge>[];
        int currId = targetNodeId;
        while (cameFromEdge.containsKey(currId)) {
          final edge = cameFromEdge[currId]!;
          path.add(edge);
          currId = edge.sourceId;
        }
        return path.reversed.toList();
      }

      openSet.remove(current);
      final currentG = gScore[current] ?? double.infinity;

      final neighbors = adjacency[current] ?? const [];
      for (final edge in neighbors) {
        final neighbor = edge.targetId;
        final tentativeG = currentG + edge.computeCost(profile);

        if (tentativeG < (gScore[neighbor] ?? double.infinity)) {
          cameFromEdge[neighbor] = edge;
          gScore[neighbor] = tentativeG;
          final neighborNode = nodes[neighbor];
          if (neighborNode != null) {
            fScore[neighbor] = tentativeG + _heuristic(neighborNode, targetNode);
          }
          openSet.add(neighbor);
        }
      }
    }

    return null; // No path found
  }

  double _heuristic(RoutingNode a, RoutingNode b) {
    // Admissible Euclidean/Haversine distance in meters
    return _distCalc.as(LengthUnit.Meter, a.toLatLng, b.toLatLng);
  }

  /// Serializes graph to compact JSON
  String toJsonString() {
    final data = {
      'nodes': nodes.values.map((n) => n.toJson()).toList(),
      'edges': <Map<String, dynamic>>[],
    };

    final edgesList = data['edges'] as List<Map<String, dynamic>>;
    final visitedEdges = <String>{};

    for (final edges in adjacency.values) {
      for (final edge in edges) {
        final key = edge.isOneWay
            ? '${edge.sourceId}->${edge.targetId}'
            : '${math.min(edge.sourceId, edge.targetId)}<->${math.max(edge.sourceId, edge.targetId)}';
        if (!visitedEdges.contains(key)) {
          visitedEdges.add(key);
          edgesList.add(edge.toJson());
        }
      }
    }

    return jsonEncode(data);
  }

  /// Deserializes graph from JSON string
  static OfflineRoutingGraph fromJsonString(String jsonString) {
    final graph = OfflineRoutingGraph();
    final data = jsonDecode(jsonString) as Map<String, dynamic>;

    if (data['nodes'] is List) {
      for (final item in data['nodes'] as List) {
        graph.addNode(RoutingNode.fromJson(item as Map<String, dynamic>));
      }
    }

    if (data['edges'] is List) {
      for (final item in data['edges'] as List) {
        graph.addEdge(RoutingEdge.fromJson(item as Map<String, dynamic>));
      }
    }

    return graph;
  }
}
