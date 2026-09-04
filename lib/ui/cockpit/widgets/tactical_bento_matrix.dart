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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LIVE BIO-MECHANICAL MATRIX',
                style: AppTypography.labelCaps.copyWith(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: AppColors.onSurfaceVariant,
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
            childAspectRatio: 1.45,
            children: [
              // 1. Heart Rate (Alert state when peak)
              MetricTile(
                icon: const Icon(Icons.favorite, color: AppColors.error, size: 14),
                label: 'Heart Rate',
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    telemetry.heartRateZone,
                    style: AppTypography.microCaps.copyWith(
                      color: AppColors.onError,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                value: '${telemetry.heartRateBpm}',
                unit: 'BPM',
                footerLeft: '>90% Max Threshold',
                footerRight: '${telemetry.vo2MaxPercent}% Vo2',
                isAlert: telemetry.isHeartRatePeakAlert,
              ),

              // 2. Speed
              MetricTile(
                label: 'Speed',
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+${telemetry.speedDeltaVsPb} vs PB',
                    style: AppTypography.microCaps.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                value: telemetry.currentSpeedKmH.toStringAsFixed(1),
                unit: 'KM/H',
                footerLeft: 'Avg ${telemetry.avgSpeedKmH} km/h',
                footerRight: 'Max ${telemetry.maxSpeedKmH}',
              ),

              // 3. Grade / Incline
              MetricTile(
                label: 'Grade / Incline',
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryFixedDim.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'STEEP WALL',
                    style: AppTypography.microCaps.copyWith(
                      color: AppColors.tertiaryFixedDim,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                value: '+${telemetry.currentGradePercent.toStringAsFixed(1)}',
                unit: '%',
                valueStyle: AppTypography.dataMetricLg.copyWith(
                  color: AppColors.tertiaryFixedDim,
                ),
                footerLeft: 'VAM ${telemetry.vamAscentRateMh} m/h',
                footerRight: 'Apex +${telemetry.maxGradePercent.toInt()}%',
              ),

              // 4. Cadence
              MetricTile(
                label: 'Cadence',
                badge: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.secondaryFixed,
                  ),
                ),
                value: '${telemetry.cadenceRpm}',
                unit: 'RPM',
                valueStyle: AppTypography.dataMetricLg.copyWith(
                  color: AppColors.secondaryFixed,
                ),
                footerLeft: 'Smoothness Index',
                footerRight: '${telemetry.cadenceSmoothnessPercent}%',
              ),

              // 5. ETA / Remain
              MetricTile(
                label: 'ETA / Remain',
                badge: Text(
                  'GAP ${telemetry.pbGhostGapSeconds}s',
                  style: AppTypography.microCaps.copyWith(
                    color: AppColors.secondaryFixed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                value: telemetry.etaFormatted.replaceAll(' AM', '').replaceAll(' PM', ''),
                unit: 'AM',
                valueStyle: AppTypography.dataMetricMd.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                footerLeft: '${telemetry.distanceRemainingKm} km to summit',
                footerRight: '${(telemetry.progressPercentage * 100).toInt()}% done',
              ),

              // 6. Output Power
              MetricTile(
                label: 'Output Power',
                badge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'FTP ${telemetry.powerFtpPercent}%',
                    style: AppTypography.microCaps.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                value: '${telemetry.powerWatts}',
                unit: 'WATTS',
                valueStyle: AppTypography.dataMetricMd.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
                footerLeft: 'NP ${telemetry.normalizedPowerWatts}W',
                footerRight: '${telemetry.wattsPerKg} W/kg',
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
