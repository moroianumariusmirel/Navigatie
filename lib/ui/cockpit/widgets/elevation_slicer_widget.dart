import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../core/models/telemetry_data.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/elevation_point.dart';

class ElevationSlicerWidget extends StatelessWidget {
  final TelemetryData telemetry;
  final RouteModel? route;
  final EdgeInsetsGeometry? margin;

  const ElevationSlicerWidget({
    super.key,
    required this.telemetry,
    this.route,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    final profile = route?.elevationProfile ?? RouteModel.sampleSchauinsland().elevationProfile;

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Ribbon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.show_chart, color: AppColors.secondaryFixed, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'ROUTE PROFILE & SLOPE SEVERITY',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelCaps.copyWith(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    'ASCENT LEFT:',
                    style: AppTypography.microCaps.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '+${telemetry.ascentRemainingM.toInt()}m',
                    style: AppTypography.labelCaps.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Vector Slicer Canvas with current position scrubber
          SizedBox(
            height: 100,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canvasWidth = constraints.maxWidth;
                final progress = telemetry.progressPercentage;
                final needleX = canvasWidth * progress;
                // Clamp scrubber pill so it stays strictly within the card bounds
                final double pillLeft = (needleX - 45.0).clamp(2.0, math.max(2.0, canvasWidth - 145.0)).toDouble();

                return Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _ElevationProfilePainter(
                          profile: profile,
                          progressRatio: progress,
                        ),
                      ),
                    ),

                    // Scrubber Pill
                    Positioned(
                      top: 2,
                      left: pillLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'YOU • KM ${telemetry.distanceTraveledKm.toStringAsFixed(1)} (${telemetry.currentElevationM.toInt()}m)',
                              style: AppTypography.microCaps.copyWith(
                                color: AppColors.onSecondaryContainer,
                                fontWeight: FontWeight.w900,
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Apex Callout Label
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'APEX ${telemetry.apexElevationM.toInt()}m',
                            style: AppTypography.microCaps.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            '+${telemetry.maxGradePercent.toStringAsFixed(1)}% MAX',
                            style: AppTypography.microCaps.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 6),

          // Distance Reference Axis
          Builder(
            builder: (context) {
              final total = telemetry.totalDistanceKm;
              final d1 = (total * 0.33).toStringAsFixed(1);
              final d2 = (total * 0.66).toStringAsFixed(1);
              final dEnd = total.toStringAsFixed(1);

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0.0 km', style: AppTypography.microCaps.copyWith(fontSize: 9)),
                  Text('$d1 km', style: AppTypography.microCaps.copyWith(fontSize: 9)),
                  Text(
                    '$d2 km',
                    style: AppTypography.microCaps.copyWith(
                      fontSize: 9,
                      color: AppColors.secondaryFixed,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '$dEnd km',
                    style: AppTypography.microCaps.copyWith(fontSize: 9),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 8),

          // Pitch Gradient Color Code Legend
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LegendItem(color: AppColors.slopeFlat, label: '0-3%'),
              _LegendItem(color: AppColors.slopeModerate, label: '4-7%'),
              _LegendItem(color: AppColors.slopeSteep, label: '8-12%'),
              _LegendItem(color: AppColors.slopeExtreme, label: '15%+ EXTREME'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.microCaps.copyWith(
            fontSize: 8,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ElevationProfilePainter extends CustomPainter {
  final List<ElevationPoint> profile;
  final double progressRatio;

  _ElevationProfilePainter({
    required this.profile,
    required this.progressRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.isEmpty) return;

    double minEle = profile.first.elevationM;
    double maxEle = profile.first.elevationM;
    for (final pt in profile) {
      if (pt.elevationM < minEle) minEle = pt.elevationM;
      if (pt.elevationM > maxEle) maxEle = pt.elevationM;
    }

    final padding = math.max(30.0, (maxEle - minEle) * 0.12);
    final chartMin = (minEle - padding).clamp(0.0, double.infinity);
    final chartMax = maxEle + padding;
    final eleRange = (chartMax - chartMin) <= 0 ? 1.0 : (chartMax - chartMin);

    final maxDistance = profile.last.distanceKm <= 0 ? 1.0 : profile.last.distanceKm;

    final points = <Offset>[];
    for (final pt in profile) {
      final x = (pt.distanceKm / maxDistance) * size.width;
      final y = size.height - ((pt.elevationM - chartMin) / eleRange) * (size.height * 0.85);
      points.add(Offset(x, y));
    }

    // 1. Fill Area
    final fillPath = Path()..moveTo(0, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.surfaceContainerHighest.withOpacity(0.8),
          AppColors.surfaceContainerLowest.withOpacity(0.3),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawPath(fillPath, fillPaint);

    // 2. Multi-Color Gradient Stroke
    final strokePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      strokePath.lineTo(points[i].dx, points[i].dy);
    }

    final strokePaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          AppColors.slopeFlat,
          AppColors.slopeModerate,
          AppColors.slopeSteep,
          AppColors.slopeExtreme,
          AppColors.slopeFlat,
        ],
        stops: [0.0, 0.35, 0.65, 0.85, 1.0],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(strokePath, strokePaint);

    // 3. Grid Lines
    final gridPaint = Paint()
      ..color = AppColors.outlineVariant.withOpacity(0.3)
      ..strokeWidth = 0.5;

    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.3), gridPaint);
    canvas.drawLine(Offset(0, size.height * 0.6), Offset(size.width, size.height * 0.6), gridPaint);

    // 4. Summit Apex Circle Marker (Point at highest elevation)
    final apexPoint = points.reduce((curr, next) => curr.dy < next.dy ? curr : next);
    final apexCirclePaint = Paint()
      ..color = AppColors.error
      ..style = PaintingStyle.fill;
    final apexBorderPaint = Paint()
      ..color = AppColors.errorContainer
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(apexPoint, 4.5, apexCirclePaint);
    canvas.drawCircle(apexPoint, 4.5, apexBorderPaint);

    // 5. User Position Needle
    final currentX = size.width * progressRatio;
    final needlePaint = Paint()
      ..color = AppColors.secondaryContainer
      ..strokeWidth = 1.5;

    // Dashed vertical line
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(currentX, startY), Offset(currentX, startY + 4), needlePaint);
      startY += 8;
    }

    // Find point on curve at currentX
    double currentY = size.height * 0.5;
    for (int i = 0; i < points.length - 1; i++) {
      if (currentX >= points[i].dx && currentX <= points[i + 1].dx) {
        final segmentW = points[i + 1].dx - points[i].dx;
        final t = segmentW > 0 ? (currentX - points[i].dx) / segmentW : 0.0;
        currentY = points[i].dy + t * (points[i + 1].dy - points[i].dy);
        break;
      }
    }

    // Needle Disc positioned directly on the elevation curve
    canvas.drawCircle(
      Offset(currentX, currentY),
      5.0,
      Paint()..color = AppColors.secondaryContainer,
    );
    canvas.drawCircle(
      Offset(currentX, currentY),
      2.5,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _ElevationProfilePainter oldDelegate) {
    return oldDelegate.progressRatio != progressRatio || oldDelegate.profile != profile;
  }
}
