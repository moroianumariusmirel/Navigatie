import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../core/models/telemetry_data.dart';
import 'metric_tile.dart';

class TacticalBentoMatrix extends StatelessWidget {
  final TelemetryData telemetry;

  const TacticalBentoMatrix({
    super.key,
    required this.telemetry,
  });

  (String, Color) _getGradeBadge(double grade) {
    if (grade <= -8.0) return ('STEEP DESCENT', AppColors.secondaryContainer);
    if (grade < -1.5) return ('DESCENT', AppColors.secondaryContainer);
    if (grade.abs() <= 1.5) return ('FLAT', AppColors.slopeFlat);
    if (grade <= 6.0) return ('MODERATE', AppColors.slopeModerate);
    if (grade <= 11.0) return ('STEEP WALL', AppColors.slopeSteep);
    return ('EXTREME PITCH', AppColors.slopeExtreme);
  }

  @override
  Widget build(BuildContext context) {
    final grade = telemetry.currentGradePercent;
    final (gradeBadgeText, gradeColor) = _getGradeBadge(grade);
    final gradeSign = grade > 0 ? '+' : '';

    final etaParts = telemetry.etaFormatted.split(' ');
    final etaTime = etaParts.isNotEmpty ? etaParts[0] : telemetry.etaFormatted;
    final etaUnit = etaParts.length > 1 ? etaParts[1] : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'LIVE BIO-MECHANICAL MATRIX',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelCaps.copyWith(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'TELEMETRY SYNC: 10HZ',
                    style: AppTypography.microCaps.copyWith(
                      color: AppColors.secondaryFixed,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Bento 2x3 Grid
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              // 1. Heart Rate (Alert state when peak)
              // 1. Heart Rate (Standby awaiting smartwatch connection)
              MetricTile(
                icon: const Icon(Icons.favorite, color: AppColors.error, size: 14),
                label: 'Heart Rate',
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: telemetry.heartRateBpm != null ? AppColors.error : AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    telemetry.heartRateBpm != null ? telemetry.heartRateZone : 'STANDBY',
                    style: AppTypography.microCaps.copyWith(
                      color: telemetry.heartRateBpm != null ? AppColors.onError : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                value: telemetry.heartRateBpm != null ? '${telemetry.heartRateBpm}' : '--',
                unit: 'BPM',
                footerLeft: telemetry.heartRateBpm != null ? '>90% Threshold' : 'Watch Standby',
                footerRight: telemetry.heartRateBpm != null ? '${telemetry.vo2MaxPercent}% Vo2' : 'BLE / Wear OS',
                isAlert: telemetry.heartRateBpm != null && telemetry.isHeartRatePeakAlert,
              ),

              // 2. Speed (Real Hardware GPS Speed)
              MetricTile(
                label: 'Speed',
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    telemetry.currentSpeedKmH > 0 ? 'LIVE GPS' : 'STATIONARY',
                    style: AppTypography.microCaps.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                value: telemetry.currentSpeedKmH.toStringAsFixed(1),
                unit: 'KM/H',
                footerLeft: telemetry.currentSpeedKmH > 0 ? '±${telemetry.gpsAccuracyM}m Acc' : 'GPS Active',
                footerRight: 'Ele ${telemetry.currentElevationM.toInt()}m',
              ),

              // 3. Grade
              MetricTile(
                label: 'Grade',
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: gradeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    gradeBadgeText,
                    style: AppTypography.microCaps.copyWith(
                      color: gradeColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                value: '$gradeSign${grade.toStringAsFixed(1)}',
                unit: '%',
                valueStyle: AppTypography.dataMetricLg.copyWith(
                  color: gradeColor,
                ),
                footerLeft: 'VAM ${telemetry.vamAscentRateMh} m/h',
                footerRight: 'Apex +${telemetry.maxGradePercent.toInt()}%',
              ),

              // 4. Cadence (Sensor Standby)
              MetricTile(
                label: 'Cadence',
                badge: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: telemetry.cadenceRpm != null ? AppColors.secondaryFixed : AppColors.outlineVariant,
                  ),
                ),
                value: telemetry.cadenceRpm != null ? '${telemetry.cadenceRpm}' : '--',
                unit: 'RPM',
                valueStyle: AppTypography.dataMetricLg.copyWith(
                  color: telemetry.cadenceRpm != null ? AppColors.secondaryFixed : AppColors.onSurfaceVariant,
                ),
                footerLeft: telemetry.cadenceRpm != null ? 'Smoothness' : 'Sensor Standby',
                footerRight: telemetry.cadenceRpm != null ? '${telemetry.cadenceSmoothnessPercent}%' : 'Awaiting Sensor',
              ),

              // 5. ETA / Remain
              MetricTile(
                label: 'ETA / Remain',
                badge: Text(
                  telemetry.isOffRoute ? 'OFF ROUTE' : 'ON TRACK',
                  style: AppTypography.microCaps.copyWith(
                    color: telemetry.isOffRoute ? AppColors.error : AppColors.secondaryFixed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                value: etaTime,
                unit: etaUnit,
                valueStyle: AppTypography.dataMetricMd.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                footerLeft: '${telemetry.distanceRemainingKm.toStringAsFixed(1)} km left',
                footerRight: '${(telemetry.progressPercentage * 100).toInt()}% done',
              ),

              // 6. Output Power (Sensor Standby)
              MetricTile(
                label: 'Output Power',
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: telemetry.powerWatts != null ? AppColors.primaryContainer : AppColors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    telemetry.powerWatts != null ? 'FTP ${telemetry.powerFtpPercent}%' : 'STANDBY',
                    style: AppTypography.microCaps.copyWith(
                      color: telemetry.powerWatts != null ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                value: telemetry.powerWatts != null ? '${telemetry.powerWatts}' : '--',
                unit: 'W',
                footerLeft: telemetry.powerWatts != null ? '${telemetry.normalizedPowerWatts}W NP' : 'Power Meter',
                footerRight: telemetry.powerWatts != null ? '${telemetry.wattsPerKg} W/kg' : 'Awaiting Sensor',
              ),
            ],
          ),
        ),

        // Helper Note
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.touch_app,
                color: AppColors.onSurfaceVariant,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'LONG-PRESS ANY TILE TO CUSTOMIZE SENSORS',
                style: AppTypography.microCaps.copyWith(
                  fontSize: 9,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
