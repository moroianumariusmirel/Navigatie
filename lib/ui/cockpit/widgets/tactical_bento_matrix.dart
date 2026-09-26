import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../core/models/telemetry_data.dart';
import '../../../core/models/route_model.dart';
import '../../../core/telemetry/telemetry_service.dart';
import 'metric_tile.dart';
import 'elevation_slicer_widget.dart';

class TacticalBentoMatrix extends StatelessWidget {
  final TelemetryData telemetry;
  final RouteModel? route;
  final List<BentoTileType> tileOrder;
  final void Function(int fromIndex, int toIndex)? onSwapTiles;
  final VoidCallback? onResetOrder;
  final void Function(BentoTileType type, bool isEnabled)? onToggleTile;

  const TacticalBentoMatrix({
    super.key,
    required this.telemetry,
    this.route,
    this.tileOrder = TelemetryService.defaultBentoTileOrder,
    this.onSwapTiles,
    this.onResetOrder,
    this.onToggleTile,
  });

  (String, Color) _getGradeBadge(double grade) {
    if (grade <= -8.0) return ('STEEP DESCENT', AppColors.secondaryContainer);
    if (grade < -1.5) return ('DESCENT', AppColors.secondaryContainer);
    if (grade.abs() <= 1.5) return ('FLAT', AppColors.slopeFlat);
    if (grade <= 6.0) return ('MODERATE', AppColors.slopeModerate);
    if (grade <= 11.0) return ('STEEP WALL', AppColors.slopeSteep);
    return ('EXTREME PITCH', AppColors.slopeExtreme);
  }

  Widget _buildTile(
    BentoTileType type,
    double grade,
    Color gradeColor,
    String gradeBadgeText,
    String gradeSign,
    String etaTime,
    String etaUnit,
  ) {
    switch (type) {
      case BentoTileType.heartRate:
        return MetricTile(
          key: const Key('metric_tile_heart_rate'),
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
        );

      case BentoTileType.speed:
        return MetricTile(
          key: const Key('metric_tile_speed'),
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
        );

      case BentoTileType.grade:
        return MetricTile(
          key: const Key('metric_tile_grade'),
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
        );

      case BentoTileType.cadence:
        return MetricTile(
          key: const Key('metric_tile_cadence'),
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
        );

      case BentoTileType.etaRemain:
        return MetricTile(
          key: const Key('metric_tile_eta_remain'),
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
        );

      case BentoTileType.outputPower:
        return MetricTile(
          key: const Key('metric_tile_output_power'),
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
        );

      case BentoTileType.routeProfile:
        return ElevationSlicerWidget(
          key: const Key('metric_tile_route_profile'),
          telemetry: telemetry,
          route: route,
          margin: EdgeInsets.zero,
        );
    }
  }

  void _showTileCustomizerBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainerHigh,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final activeSet = tileOrder.toSet();

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.outlineVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CUSTOMIZE COCKPIT TILES',
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelCaps.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Toggle visible telemetry metrics & profiles',
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.microCaps.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.outlineVariant.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                '${activeSet.length}/${BentoTileType.values.length} ACTIVE',
                                style: AppTypography.microCaps.copyWith(
                                  color: AppColors.secondaryFixed,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              key: const Key('cockpit_close_customizer_button'),
                              onTap: () => Navigator.of(sheetContext).pop(),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLowest,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.outlineVariant.withOpacity(0.3),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.outlineVariant, height: 1),
                    const SizedBox(height: 6),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: BentoTileType.values.length,
                        separatorBuilder: (context, index) => const Divider(
                          color: AppColors.outlineVariant,
                          height: 1,
                          indent: 52,
                        ),
                        itemBuilder: (context, index) {
                          final type = BentoTileType.values[index];
                          final isEnabled = activeSet.contains(type);

                          final (iconData, iconColor) = switch (type) {
                            BentoTileType.heartRate => (Icons.favorite_rounded, AppColors.error),
                            BentoTileType.speed => (Icons.speed_rounded, AppColors.primary),
                            BentoTileType.grade => (Icons.trending_up_rounded, AppColors.slopeSteep),
                            BentoTileType.cadence => (Icons.directions_bike_rounded, AppColors.secondaryFixed),
                            BentoTileType.etaRemain => (Icons.schedule_rounded, AppColors.primary),
                            BentoTileType.outputPower => (Icons.bolt_rounded, AppColors.primaryContainer),
                            BentoTileType.routeProfile => (Icons.area_chart_rounded, AppColors.secondaryFixed),
                          };

                          return SwitchListTile(
                            key: Key('toggle_tile_${type.name}'),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            secondary: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(iconData, color: iconColor, size: 20),
                            ),
                            title: Text(
                              type.title,
                              style: AppTypography.labelCaps.copyWith(
                                color: AppColors.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              type.description,
                              style: AppTypography.microCaps.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 9,
                              ),
                            ),
                            value: isEnabled,
                            activeColor: AppColors.primary,
                            onChanged: (activeSet.length <= 1 && isEnabled)
                                ? null
                                : (bool val) {
                                    HapticFeedback.selectionClick();
                                    if (val) {
                                      activeSet.add(type);
                                    } else {
                                      activeSet.remove(type);
                                    }
                                    onToggleTile?.call(type, val);
                                    setSheetState(() {});
                                  },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
              InkWell(
                key: const Key('cockpit_edit_tiles_button'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showTileCustomizerBottomSheet(context);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'EDIT TILES',
                        style: AppTypography.microCaps.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  if (onResetOrder != null) ...[
                    InkWell(
                      key: const Key('cockpit_reset_tiles_button'),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onResetOrder?.call();
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.refresh_rounded,
                              size: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'RESET',
                              style: AppTypography.microCaps.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
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

        // Bento Tiles Flow with Long-Press Drag-and-Drop Reordering
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final itemWidth = (totalWidth - 10) / 2;
              final itemHeight = itemWidth / 1.35;

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(tileOrder.length, (index) {
                  final type = tileOrder[index];
                  final isFull = type.isFullWidth;
                  final tileWidth = isFull ? totalWidth : itemWidth;
                  final tileHeight = isFull ? 195.0 : itemHeight;

                  final tileWidget = _buildTile(
                    type,
                    grade,
                    gradeColor,
                    gradeBadgeText,
                    gradeSign,
                    etaTime,
                    etaUnit,
                  );

                  return SizedBox(
                    width: tileWidth,
                    height: isFull ? null : tileHeight,
                    child: DragTarget<int>(
                      onWillAcceptWithDetails: (details) => details.data != index,
                      onAcceptWithDetails: (details) {
                        HapticFeedback.mediumImpact();
                        onSwapTiles?.call(details.data, index);
                      },
                      builder: (context, candidateData, rejectedData) {
                        final isHovered = candidateData.isNotEmpty;

                        return LongPressDraggable<int>(
                          data: index,
                          delay: const Duration(milliseconds: 250),
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: tileWidth,
                              height: isFull ? null : tileHeight,
                              child: Transform.scale(
                                scale: 1.05,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.45),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: tileWidget,
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: SizedBox(
                            width: tileWidth,
                            height: tileHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.outline.withOpacity(0.35),
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.open_with_rounded,
                                      color: AppColors.outline.withOpacity(0.5),
                                      size: 22,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'MOVE HERE',
                                      style: AppTypography.microCaps.copyWith(
                                        color: AppColors.outline.withOpacity(0.6),
                                        fontSize: 8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: isHovered
                                  ? Border.all(color: AppColors.primary, width: 2.0)
                                  : null,
                              boxShadow: isHovered
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.35),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: tileWidget,
                          ),
                        );
                      },
                    ),
                  );
                }),
              );
            },
          ),
        ),

        // Helper Note
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.touch_app_rounded,
                color: AppColors.primary,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                'HOLD & DRAG ANY TILE TO REARRANGE COCKPIT',
                style: AppTypography.microCaps.copyWith(
                  fontSize: 9,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
