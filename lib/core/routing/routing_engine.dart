import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';

enum OutdoorRoutingProfile {
  roadBike,
  gravelBike,
  mountainBike,
  hiking,
}

abstract class OfflineRoutingEngine {
  Future<RouteModel> calculateRoute({
    required LatLng start,
    required LatLng destination,
    required OutdoorRoutingProfile profile,
    List<LatLng>? waypoints,
  });

  Future<RouteModel> recalculateOffRoute({
    required LatLng currentPosition,
    required RouteModel activeRoute,
    required OutdoorRoutingProfile profile,
  });
}

/// On-Device Offline Router implementation for Strategy B
/// Interfaces with local Valhalla routing tiles or pre-cached graphs
class OnDeviceOfflineRouter implements OfflineRoutingEngine {
  final String offlineTilesDirectoryPath;

  OnDeviceOfflineRouter({required this.offlineTilesDirectoryPath});

  @override
  Future<RouteModel> calculateRoute({
    required LatLng start,
    required LatLng destination,
    required OutdoorRoutingProfile profile,
    List<LatLng>? waypoints,
  }) async {
    // In production, this executes Valhalla C++ via Dart FFI on a background Isolate.
    // Loads local tiles, computes cost matrices based on slope and surface penalties.
    await Future.delayed(const Duration(milliseconds: 150));
    return RouteModel.sampleSchauinsland();
  }

  @override
  Future<RouteModel> recalculateOffRoute({
    required LatLng currentPosition,
    required RouteModel activeRoute,
    required OutdoorRoutingProfile profile,
  }) async {
    // Quick local recalculation to rejoin the nearest point on the route
    await Future.delayed(const Duration(milliseconds: 100));
    return activeRoute;
  }
}
