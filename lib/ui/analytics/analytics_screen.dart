import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../core/telemetry/telemetry_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final telemetryService = context.watch<TelemetryService>();
    final telemetry = telemetryService.currentData;
    final activeRoute = telemetryService.activeRoute;
    final lastSummary = telemetryService.lastSessionSummary;
    final slopeDist = telemetryService.slopeDistribution;
    final isNavigating = telemetryService.isNavigating;
    final climbedSoFarM = telemetryService.climbedSoFarM;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'TERRAIN & EXERTION ANALYTICS',
          style: AppTypography.headlineSm.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Performance / Session Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.outlineVariant.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SESSION SUMMARY',
                        style: AppTypography.microCaps.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isNavigating
                              ? AppColors.primaryContainer.withOpacity(0.2)
                              : (lastSummary != null
                                  ? AppColors.surfaceBright
                                  : AppColors.surfaceContainerLowest),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isNavigating
                              ? 'NAVIGATING'
                              : (lastSummary != null ? 'STOPPED • SAVED' : 'STANDBY'),
                          style: AppTypography.microCaps.copyWith(
                            color: isNavigating
                                ? AppColors.primaryContainer
                                : (lastSummary != null
                                    ? AppColors.primaryFixedDim
                                    : AppColors.onSurfaceVariant),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // TOP ROW: Live in-flight metrics
                  Text(
                    'LIVE IN-FLIGHT PROGRESS',
                    style: AppTypography.microCaps.copyWith(
                      color: AppColors.secondaryFixedDim,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _AnalyticsItem(
                          label: 'CLIMBED SO FAR',
                          value: isNavigating || climbedSoFarM > 0
                              ? '+${climbedSoFarM.toInt()}m'
                              : '+0m',
                          valueColor: AppColors.secondaryFixed,
                        ),
                      ),
                      Expanded(
                        child: _AnalyticsItem(
                          label: 'ACTUAL ELEVATION',
                          value: telemetry.currentElevationM > 0
                              ? '${telemetry.currentElevationM.toInt()}m'
                              : '--',
                          valueColor: AppColors.primary,
                        ),
                      ),
                      Expanded(
                        child: _AnalyticsItem(
                          label: 'TIME TO FINISH',
                          value: telemetryService.timeToFinishFormatted,
                          subtitle: isNavigating && telemetry.etaFormatted != '--:--'
                              ? 'ETA ${telemetry.etaFormatted}'
                              : null,
                          valueColor: AppColors.secondaryFixedDim,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  Divider(
                    color: AppColors.outlineVariant.withOpacity(0.3),
                    height: 1,
                  ),
                  const SizedBox(height: 14),

                  // BOTTOM ROW: Completed ride summary (populated on navigation stop)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'COMPLETED RIDE SUMMARY',
                        style: AppTypography.microCaps.copyWith(
                          color: lastSummary != null
                              ? AppColors.primaryContainer
                              : AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (lastSummary == null)
                        Text(
                          'POPULATED ON STOP',
                          style: AppTypography.microCaps.copyWith(
                            color: AppColors.outline,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _AnalyticsItem(
                          label: 'TOTAL CLIMB',
                          value: lastSummary != null
                              ? '+${lastSummary.totalClimbM.toInt()}m'
                              : '--',
                          valueColor: lastSummary != null
                              ? AppColors.primaryContainer
                              : AppColors.outline,
                        ),
                      ),
                      Expanded(
                        child: _AnalyticsItem(
                          label: 'AVG SPEED',
                          value: lastSummary != null
                              ? '${lastSummary.avgSpeedKmH.toStringAsFixed(1)} km/h'
                              : '--',
                          valueColor: lastSummary != null
                              ? AppColors.primary
                              : AppColors.outline,
                        ),
                      ),
                      Expanded(
                        child: _AnalyticsItem(
                          label: 'TOTAL TIME',
                          value: lastSummary != null
                              ? lastSummary.formattedDuration
                              : '--',
                          valueColor: lastSummary != null
                              ? AppColors.secondaryFixed
                              : AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Gradient Distribution Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SLOPE GRADIENT DISTRIBUTION',
                  style: AppTypography.labelCaps.copyWith(color: AppColors.onSurfaceVariant),
                ),
                if (activeRoute != null)
                  Flexible(
                    child: Text(
                      '${activeRoute.name} (${activeRoute.totalDistanceKm} km)',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.microCaps.copyWith(
                        color: AppColors.secondaryFixedDim,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.outlineVariant.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  _ZoneBar(
                    label: '0 - 3% (Flat / Rollers)',
                    percentage: slopeDist.flatRollersPercentage,
                    distanceKm: slopeDist.flatRollersKm,
                    color: AppColors.slopeFlat,
                  ),
                  _ZoneBar(
                    label: '4 - 7% (Moderate Climb)',
                    percentage: slopeDist.moderateClimbPercentage,
                    distanceKm: slopeDist.moderateClimbKm,
                    color: AppColors.slopeModerate,
                  ),
                  _ZoneBar(
                    label: '8 - 12% (Steep Alpine)',
                    percentage: slopeDist.steepAlpinePercentage,
                    distanceKm: slopeDist.steepAlpineKm,
                    color: AppColors.slopeSteep,
                  ),
                  _ZoneBar(
                    label: '15%+ (Extreme Wall)',
                    percentage: slopeDist.extremeWallPercentage,
                    distanceKm: slopeDist.extremeWallKm,
                    color: AppColors.slopeExtreme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsItem extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color? valueColor;

  const _AnalyticsItem({
    required this.label,
    required this.value,
    this.subtitle,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.microCaps.copyWith(
            fontSize: 9.5,
            letterSpacing: 0.5,
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.dataMetricMd.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: valueColor ?? AppColors.onSurface,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 1),
          Text(
            subtitle!,
            style: AppTypography.microCaps.copyWith(
              fontSize: 8.5,
              color: AppColors.outline,
            ),
          ),
        ],
      ],
    );
  }
}

class _ZoneBar extends StatelessWidget {
  final String label;
  final double percentage;
  final double distanceKm;
  final Color color;

  const _ZoneBar({
    required this.label,
    required this.percentage,
    this.distanceKm = 0.0,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pctInt = (percentage * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTypography.bodySm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (distanceKm > 0) ...[
                    Text(
                      '${distanceKm.toStringAsFixed(1)} km  ',
                      style: AppTypography.microCaps.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  Text(
                    '$pctInt%',
                    style: AppTypography.microCaps.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: AppColors.surfaceContainerLowest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
