import 'package:latlong2/latlong.dart' hide Path;

/// Complete live bio-mechanical and spatial telemetry snapshot
class TelemetryData {
  // Speed
  final double currentSpeedKmH;
  final double speedDeltaVsPb;
  final double avgSpeedKmH;
  final double maxSpeedKmH;

  // Elevation & Slope
  final double currentElevationM;
  final double currentGradePercent;
  final int vamAscentRateMh; // Vertical Ascent Meters / Hour
  final double apexElevationM;
  final double maxGradePercent;
  final double ascentRemainingM;

  // Biometrics (null when awaiting smartwatch connection)
  final int? heartRateBpm;
  final String heartRateZone;
  final bool isHeartRatePeakAlert;
  final int vo2MaxPercent;

  // Cadence & Dynamics (null when awaiting bike sensor)
  final int? cadenceRpm;
  final int cadenceSmoothnessPercent;

  // Power & Exertion (null when awaiting power meter)
  final int? powerWatts;
  final int powerFtpPercent;
  final int normalizedPowerWatts;
  final double? wattsPerKg;

  // Distance & Navigation Progress
  final double distanceTraveledKm;
  final double distanceRemainingKm;
  final double totalDistanceKm;
  final String etaFormatted;
  final int pbGhostGapSeconds; // negative means ahead of PB

  // GPS & Fix
  final int satellitesCount;
  final double gpsAccuracyM;
  final double currentHeadingDegrees;
  final double crossTrackDistanceM;
  final bool isOffRoute;
  final double? currentLatitude;
  final double? currentLongitude;

  LatLng? get currentPosition =>
      (currentLatitude != null && currentLongitude != null)
          ? LatLng(currentLatitude!, currentLongitude!)
          : null;

  const TelemetryData({
    this.currentSpeedKmH = 0.0,
    this.speedDeltaVsPb = 0.0,
    this.avgSpeedKmH = 0.0,
    this.maxSpeedKmH = 0.0,
    this.currentElevationM = 0.0,
    this.currentGradePercent = 0.0,
    this.vamAscentRateMh = 0,
    this.apexElevationM = 0.0,
    this.maxGradePercent = 0.0,
    this.ascentRemainingM = 0.0,
    this.heartRateBpm,
    this.heartRateZone = 'STANDBY',
    this.isHeartRatePeakAlert = false,
    this.vo2MaxPercent = 0,
    this.cadenceRpm,
    this.cadenceSmoothnessPercent = 0,
    this.powerWatts,
    this.powerFtpPercent = 0,
    this.normalizedPowerWatts = 0,
    this.wattsPerKg,
    this.distanceTraveledKm = 0.0,
    this.distanceRemainingKm = 0.0,
    this.totalDistanceKm = 0.0,
    this.etaFormatted = '--:--',
    this.pbGhostGapSeconds = 0,
    this.satellitesCount = 0,
    this.gpsAccuracyM = 0.0,
    this.currentHeadingDegrees = 0.0,
    this.crossTrackDistanceM = 0.0,
    this.isOffRoute = false,
    this.currentLatitude,
    this.currentLongitude,
  });

  bool get isWatchConnected => heartRateBpm != null;
  bool get hasCadenceSensor => cadenceRpm != null;
  bool get hasPowerMeter => powerWatts != null;

  double get progressPercentage {
    if (totalDistanceKm <= 0) return 0.0;
    return (distanceTraveledKm / totalDistanceKm).clamp(0.0, 1.0);
  }

  TelemetryData copyWith({
    double? currentSpeedKmH,
    double? speedDeltaVsPb,
    double? avgSpeedKmH,
    double? maxSpeedKmH,
    double? currentElevationM,
    double? currentGradePercent,
    int? vamAscentRateMh,
    double? apexElevationM,
    double? maxGradePercent,
    double? ascentRemainingM,
    int? heartRateBpm,
    String? heartRateZone,
    bool? isHeartRatePeakAlert,
    int? vo2MaxPercent,
    int? cadenceRpm,
    int? cadenceSmoothnessPercent,
    int? powerWatts,
    int? powerFtpPercent,
    int? normalizedPowerWatts,
    double? wattsPerKg,
    double? distanceTraveledKm,
    double? distanceRemainingKm,
    double? totalDistanceKm,
    String? etaFormatted,
    int? pbGhostGapSeconds,
    int? satellitesCount,
    double? gpsAccuracyM,
    double? currentHeadingDegrees,
    double? crossTrackDistanceM,
    bool? isOffRoute,
    double? currentLatitude,
    double? currentLongitude,
  }) {
    return TelemetryData(
      currentSpeedKmH: currentSpeedKmH ?? this.currentSpeedKmH,
      speedDeltaVsPb: speedDeltaVsPb ?? this.speedDeltaVsPb,
      avgSpeedKmH: avgSpeedKmH ?? this.avgSpeedKmH,
      maxSpeedKmH: maxSpeedKmH ?? this.maxSpeedKmH,
      currentElevationM: currentElevationM ?? this.currentElevationM,
      currentGradePercent: currentGradePercent ?? this.currentGradePercent,
      vamAscentRateMh: vamAscentRateMh ?? this.vamAscentRateMh,
      apexElevationM: apexElevationM ?? this.apexElevationM,
      maxGradePercent: maxGradePercent ?? this.maxGradePercent,
      ascentRemainingM: ascentRemainingM ?? this.ascentRemainingM,
      heartRateBpm: heartRateBpm ?? this.heartRateBpm,
      heartRateZone: heartRateZone ?? this.heartRateZone,
      isHeartRatePeakAlert: isHeartRatePeakAlert ?? this.isHeartRatePeakAlert,
      vo2MaxPercent: vo2MaxPercent ?? this.vo2MaxPercent,
      cadenceRpm: cadenceRpm ?? this.cadenceRpm,
      cadenceSmoothnessPercent: cadenceSmoothnessPercent ?? this.cadenceSmoothnessPercent,
      powerWatts: powerWatts ?? this.powerWatts,
      powerFtpPercent: powerFtpPercent ?? this.powerFtpPercent,
      normalizedPowerWatts: normalizedPowerWatts ?? this.normalizedPowerWatts,
      wattsPerKg: wattsPerKg ?? this.wattsPerKg,
      distanceTraveledKm: distanceTraveledKm ?? this.distanceTraveledKm,
      distanceRemainingKm: distanceRemainingKm ?? this.distanceRemainingKm,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      etaFormatted: etaFormatted ?? this.etaFormatted,
      pbGhostGapSeconds: pbGhostGapSeconds ?? this.pbGhostGapSeconds,
      satellitesCount: satellitesCount ?? this.satellitesCount,
      gpsAccuracyM: gpsAccuracyM ?? this.gpsAccuracyM,
      currentHeadingDegrees: currentHeadingDegrees ?? this.currentHeadingDegrees,
      crossTrackDistanceM: crossTrackDistanceM ?? this.crossTrackDistanceM,
      isOffRoute: isOffRoute ?? this.isOffRoute,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
    );
  }
}
