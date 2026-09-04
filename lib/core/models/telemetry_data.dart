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

  // Biometrics
  final int heartRateBpm;
  final String heartRateZone;
  final bool isHeartRatePeakAlert;
  final int vo2MaxPercent;

  // Cadence & Dynamics
  final int cadenceRpm;
  final int cadenceSmoothnessPercent;

  // Power & Exertion
  final int powerWatts;
  final int powerFtpPercent;
  final int normalizedPowerWatts;
  final double wattsPerKg;

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

  const TelemetryData({
    this.currentSpeedKmH = 34.2,
    this.speedDeltaVsPb = 4.1,
    this.avgSpeedKmH = 23.8,
    this.maxSpeedKmH = 58.4,
    this.currentElevationM = 1811.0,
    this.currentGradePercent = 10.8,
    this.vamAscentRateMh = 1150,
    this.apexElevationM = 2191.0,
    this.maxGradePercent = 16.2,
    this.ascentRemainingM = 380.0,
    this.heartRateBpm = 176,
    this.heartRateZone = 'Z5 PEAK',
    this.isHeartRatePeakAlert = true,
    this.vo2MaxPercent = 96,
    this.cadenceRpm = 88,
    this.cadenceSmoothnessPercent = 89,
    this.powerWatts = 310,
    this.powerFtpPercent = 112,
    this.normalizedPowerWatts = 284,
    this.wattsPerKg = 4.2,
    this.distanceTraveledKm = 24.1,
    this.distanceRemainingKm = 18.4,
    this.totalDistanceKm = 42.5,
    this.etaFormatted = '11:42 AM',
    this.pbGhostGapSeconds = -14,
    this.satellitesCount = 18,
    this.gpsAccuracyM = 1.2,
    this.currentHeadingDegrees = 315.0,
    this.crossTrackDistanceM = 1.5,
    this.isOffRoute = false,
  });

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
    );
  }
}
