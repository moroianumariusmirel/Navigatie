import 'package:latlong2/latlong.dart';

class MapMatchResult {
  final LatLng snappedPosition;
  final double crossTrackDistanceMeters;
  final bool isOffRoute;
  final int nearestSegmentIndex;

  const MapMatchResult({
    required this.snappedPosition,
    required this.crossTrackDistanceMeters,
    required this.isOffRoute,
    required this.nearestSegmentIndex,
  });
}

class MapMatcher {
  static const double offRouteThresholdMeters = 30.0;
  final Distance distance = const Distance();

  MapMatchResult matchToRoute({
    required LatLng gpsPosition,
    required List<LatLng> routePoints,
  }) {
    if (routePoints.isEmpty) {
      return MapMatchResult(
        snappedPosition: gpsPosition,
        crossTrackDistanceMeters: 0.0,
        isOffRoute: false,
        nearestSegmentIndex: 0,
      );
    }

    double minDistance = double.infinity;
    int nearestIndex = 0;

    for (int i = 0; i < routePoints.length; i++) {
      final d = distance.as(LengthUnit.Meter, gpsPosition, routePoints[i]);
      if (d < minDistance) {
        minDistance = d;
        nearestIndex = i;
      }
    }

    final isOff = minDistance > offRouteThresholdMeters;

    return MapMatchResult(
      snappedPosition: routePoints[nearestIndex],
      crossTrackDistanceMeters: minDistance,
      isOffRoute: isOff,
      nearestSegmentIndex: nearestIndex,
    );
  }
}
