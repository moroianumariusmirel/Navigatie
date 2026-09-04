class ElevationPoint {
  final double distanceKm;
  final double elevationM;
  final double gradePercent;
  final double? latitude;
  final double? longitude;

  const ElevationPoint({
    required this.distanceKm,
    required this.elevationM,
    required this.gradePercent,
    this.latitude,
    this.longitude,
  });
}
