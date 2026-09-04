import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../core/models/telemetry_data.dart';
import '../../../core/models/maneuver_instruction.dart';
import 'turn_guidance_banner.dart';

class PerspectiveMapView extends StatefulWidget {
  final TelemetryData telemetry;
  final ManeuverInstruction maneuver;

  const PerspectiveMapView({
    super.key,
    required this.telemetry,
    required this.maneuver,
  });

  @override
  State<PerspectiveMapView> createState() => _PerspectiveMapViewState();
}

class _PerspectiveMapViewState extends State<PerspectiveMapView>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 380,
      width: double.infinity,
      color: AppColors.surfaceContainerLowest,
      child: Stack(
        children: [
          // 3D Perspective Plane & Contour lines
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _radarController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _TerrainPerspectivePainter(
                    animationProgress: _radarController.value,
                    heading: widget.telemetry.currentHeadingDegrees,
                  ),
                );
              },
            ),
          ),

          // Turn Guidance Banner at top of map
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: TurnGuidanceBanner(maneuver: widget.maneuver),
          ),

          // PB Ghost Badge
          Positioned(
            top: 152,
            left: 230,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh.withOpacity(0.92),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.secondaryFixed,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'PB GHOST (-14s)',
                    style: AppTypography.labelCaps.copyWith(
                      fontSize: 9,
                      color: AppColors.secondaryFixed,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Left: 3D Dynamic Tilt Pill
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest.withOpacity(0.92),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryContainer,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '3D TILT 45° • ${widget.telemetry.currentSpeedKmH.toInt()} KM/H',
                    style: AppTypography.microCaps.copyWith(
                      color: AppColors.onSurface,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Right: GPS Satellite Telemetry & Action Buttons
          Positioned(
            bottom: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${widget.telemetry.satellitesCount} SATS • ±${widget.telemetry.gpsAccuracyM}m',
                    style: AppTypography.microCaps.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _MapCircularButton(
                  icon: Icons.near_me,
                  color: AppColors.primary,
                  onTap: () {},
                ),
                const SizedBox(width: 8),
                _MapCircularButton(
                  icon: Icons.layers,
                  color: AppColors.secondaryFixed,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapCircularButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MapCircularButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withOpacity(0.92),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 6,
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _TerrainPerspectivePainter extends CustomPainter {
  final double animationProgress;
  final double heading;

  _TerrainPerspectivePainter({
    required this.animationProgress,
    required this.heading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Radial Glow Background
    final rect = Offset.zero & size;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.2, 0.1),
        radius: 0.8,
        colors: [
          AppColors.primaryContainer.withOpacity(0.18),
          AppColors.secondaryContainer.withOpacity(0.08),
          AppColors.background,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, glowPaint);

    // 2. 3D Perspective Wire Grid Floor
    final gridPaint = Paint()
      ..color = AppColors.surfaceContainerHigh.withOpacity(0.65)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final vanishingPoint = Offset(size.width * 0.5, size.height * 0.22);
    final bottomY = size.height;

    // Perspective ray lines radiating from horizon
    final xCoords = [-50.0, 40.0, 120.0, 200.0, 280.0, 360.0, 450.0];
    for (final x in xCoords) {
      canvas.drawLine(vanishingPoint, Offset(x, bottomY), gridPaint);
    }

    // Perspective depth rings
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.55), width: 320, height: 48),
      gridPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.72), width: 440, height: 68),
      gridPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(size.width * 0.5, size.height * 0.90), width: 560, height: 92),
      gridPaint,
    );

    // 3. Topographic Contours (IGN style)
    final topoPaint = Paint()
      ..color = AppColors.outlineVariant.withOpacity(0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final topoPath = Path();
    topoPath.moveTo(0, size.height * 0.4);
    topoPath.cubicTo(
      size.width * 0.3, size.height * 0.35,
      size.width * 0.7, size.height * 0.45,
      size.width, size.height * 0.38,
    );
    topoPath.moveTo(0, size.height * 0.6);
    topoPath.cubicTo(
      size.width * 0.25, size.height * 0.52,
      size.width * 0.65, size.height * 0.68,
      size.width, size.height * 0.55,
    );
    canvas.drawPath(topoPath, topoPaint);

    // 4. Primary Active Route Neon Polyline
    final routeGlowPaint = Paint()
      ..color = AppColors.secondaryContainer.withOpacity(0.4)
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final routeSolidPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          AppColors.secondaryFixedDim,
          AppColors.secondaryContainer,
          AppColors.primaryContainer,
        ],
      ).createShader(rect)
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final routePath = Path();
    routePath.moveTo(size.width * 0.1, size.height * 0.92);
    routePath.cubicTo(
      size.width * 0.3, size.height * 0.8,
      size.width * 0.45, size.height * 0.65,
      size.width * 0.6, size.height * 0.42,
    );
    routePath.cubicTo(
      size.width * 0.7, size.height * 0.3,
      size.width * 0.8, size.height * 0.25,
      size.width * 0.92, size.height * 0.18,
    );

    canvas.drawPath(routePath, routeGlowPaint);
    canvas.drawPath(routePath, routeSolidPaint);

    // 5. User Position Radar & Beacon (at ~60% down the route)
    final userPos = Offset(size.width * 0.45, size.height * 0.62);

    // Radar cone sweep
    final radarPaint = Paint()
      ..shader = SweepGradient(
        center: FractionalOffset(userPos.dx / size.width, userPos.dy / size.height),
        startAngle: 0.0,
        endAngle: math.pi * 2,
        colors: [
          AppColors.primaryContainer.withOpacity(0.0),
          AppColors.primaryContainer.withOpacity(0.35),
        ],
        transform: GradientRotation(animationProgress * math.pi * 2),
      ).createShader(Rect.fromCircle(center: userPos, radius: 45))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(userPos, 45, radarPaint);

    // Pulsing ping ring
    final pingRadius = 16.0 + (animationProgress * 16.0);
    final pingPaint = Paint()
      ..color = AppColors.primaryContainer.withOpacity(1.0 - animationProgress)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(userPos, pingRadius, pingPaint);

    // Central Navigator Disc
    final centerDiscPaint = Paint()
      ..color = AppColors.primaryFixed
      ..style = PaintingStyle.fill;
    canvas.drawCircle(userPos, 9, centerDiscPaint);

    final arrowPaint = Paint()
      ..color = AppColors.onPrimaryContainer
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Heading arrow
    final arrowPath = Path();
    arrowPath.moveTo(userPos.dx, userPos.dy - 6);
    arrowPath.lineTo(userPos.dx - 4, userPos.dy + 4);
    arrowPath.lineTo(userPos.dx, userPos.dy + 2);
    arrowPath.lineTo(userPos.dx + 4, userPos.dy + 4);
    arrowPath.close();
    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _TerrainPerspectivePainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.heading != heading;
  }
}
