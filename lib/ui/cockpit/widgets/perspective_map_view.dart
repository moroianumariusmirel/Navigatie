import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../core/models/telemetry_data.dart';
import '../../../core/models/maneuver_instruction.dart';
import '../../../core/models/route_model.dart';
import '../../../core/models/activity_type.dart';
import '../../../core/maps/osm_tile_providers.dart';
import '../../../core/navigation/audio_navigation_service.dart';
import '../../../core/telemetry/telemetry_service.dart';
import 'turn_guidance_banner.dart';

class PerspectiveMapView extends StatefulWidget {
  final TelemetryData telemetry;
  final ManeuverInstruction maneuver;
  final RouteModel? route;
  final ActivityType activityType;
  final NavigationAudioMode audioMode;
  final ValueChanged<NavigationAudioMode>? onAudioModeChanged;
  final NavigationState navigationState;
  final VoidCallback? onPlayPause;
  final VoidCallback? onStop;

  const PerspectiveMapView({
    super.key,
    required this.telemetry,
    required this.maneuver,
    this.route,
    this.activityType = ActivityType.cycling,
    this.audioMode = NavigationAudioMode.voiceAndChimes,
    this.onAudioModeChanged,
    this.navigationState = NavigationState.stopped,
    this.onPlayPause,
    this.onStop,
  });

  @override
  State<PerspectiveMapView> createState() => _PerspectiveMapViewState();
}

class _PerspectiveMapViewState extends State<PerspectiveMapView>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  late final MapController _mapController;
  bool _showLiveOsm = true;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant PerspectiveMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newPos = widget.telemetry.currentPosition;
    if (newPos != null && newPos != oldWidget.telemetry.currentPosition) {
      _mapController.move(newPos, _mapController.camera.zoom);
    }
    if (widget.telemetry.currentHeadingDegrees != oldWidget.telemetry.currentHeadingDegrees) {
      _mapController.rotate(widget.telemetry.currentHeadingDegrees);
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCycling = widget.activityType == ActivityType.cycling;
    final primaryTheme = isCycling ? AppColors.primaryContainer : AppColors.secondaryContainer;

    // Determine current user coordinate along route
    final userPos = widget.telemetry.currentPosition ??
        (widget.route?.coordinates.isNotEmpty == true
            ? widget.route!.coordinates.first
            : const LatLng(47.912, 7.898));

    return Container(
      height: 380,
      width: double.infinity,
      color: AppColors.surfaceContainerLowest,
      child: Stack(
        children: [
          // 1. BASE LAYER: Either Live OpenStreetMap (CyclOSM/OpenTopoMap) OR 3D Vector Terrain
          if (_showLiveOsm) ...[
            Positioned.fill(
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: userPos,
                  initialZoom: 14.2,
                  initialRotation: widget.telemetry.currentHeadingDegrees,
                  minZoom: 6.0,
                  maxZoom: 19.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  // Dedicated OpenStreetMap tile provider for Cycling vs Hiking
                  OsmTileProviders.layerForActivity(widget.activityType),

                  // Route Polyline with dual-pass neon glow
                  if (widget.route != null && widget.route!.coordinates.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: widget.route!.coordinates,
                          strokeWidth: 8.0,
                          color: primaryTheme.withOpacity(0.35),
                        ),
                        Polyline(
                          points: widget.route!.coordinates,
                          strokeWidth: 4.0,
                          color: primaryTheme,
                        ),
                      ],
                    ),

                  // Live User Position Beacon with Heading Indicator
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: userPos,
                        width: 44,
                        height: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Pulsing radar halo
                            AnimatedBuilder(
                              animation: _radarController,
                              builder: (context, child) {
                                return Container(
                                  width: 28 + (_radarController.value * 16),
                                  height: 28 + (_radarController.value * 16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: primaryTheme.withOpacity(1.0 - _radarController.value),
                                      width: 2,
                                    ),
                                  ),
                                );
                              },
                            ),
                            // User beacon center with heading pointer
                            Transform.rotate(
                              angle: (widget.telemetry.currentHeadingDegrees * (math.pi / 180.0)),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Pointer triangle
                                  Transform.translate(
                                    offset: const Offset(0, -9),
                                    child: Icon(Icons.arrow_drop_up, color: primaryTheme, size: 22),
                                  ),
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: primaryTheme,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 2.5),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black54, blurRadius: 4),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Translucent Tactical Radar Sweep Overlay over the Map
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _radarController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _CockpitRadarSweepPainter(
                        progress: _radarController.value,
                        themeColor: primaryTheme,
                      ),
                    );
                  },
                ),
              ),
            ),
          ] else ...[
            // 3D Perspective Plane & Contour lines (Original Vector Canvas)
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
          ],

          // 2. TOP HUD: Turn Guidance Banner
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: TurnGuidanceBanner(
              maneuver: widget.maneuver,
              audioMode: widget.audioMode,
              onAudioModeChanged: widget.onAudioModeChanged,
              isOffRoute: widget.telemetry.isOffRoute,
              navigationState: widget.navigationState,
              onPlayPause: widget.onPlayPause,
              onStop: widget.onStop,
            ),
          ),

          // 3. PB Ghost Badge
          Positioned(
            top: 152,
            right: 12,
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
                    'PB GHOST (${widget.telemetry.pbGhostGapSeconds}s)',
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

          // 4. BOTTOM LEFT: Interactive Mode Switch (Live OSM vs 3D Radar)
          Positioned(
            bottom: 12,
            left: 12,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showLiveOsm = !_showLiveOsm;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: primaryTheme.withOpacity(0.5),
                    width: 1,
                  ),
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
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryTheme,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showLiveOsm
                          ? (isCycling ? '🗺️ CYCLOSM LIVE' : '🥾 OPENTOPOMAP LIVE')
                          : '📐 3D PERSPECTIVE',
                      style: AppTypography.microCaps.copyWith(
                        color: AppColors.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.sync, size: 11, color: AppColors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),

          // 5. BOTTOM RIGHT: Zoom Controls & Satellite Telemetry
          Positioned(
            bottom: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showLiveOsm) ...[
                  _MiniZoomButton(
                    icon: Icons.my_location,
                    onTap: () {
                      _mapController.move(userPos, 16.0);
                    },
                  ),
                  const SizedBox(width: 4),
                  _MiniZoomButton(
                    icon: Icons.add,
                    onTap: () {
                      final zoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, zoom + 1);
                    },
                  ),
                  const SizedBox(width: 4),
                  _MiniZoomButton(
                    icon: Icons.remove,
                    onTap: () {
                      final zoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, zoom - 1);
                    },
                  ),
                  const SizedBox(width: 6),
                ],
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MiniZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest.withOpacity(0.92),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
      ),
    );
  }
}

/// Translucent radar sweep line over the live map
class _CockpitRadarSweepPainter extends CustomPainter {
  final double progress;
  final Color themeColor;

  _CockpitRadarSweepPainter({required this.progress, required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.55);
    final maxRadius = size.width * 0.45;

    final sweepPaint = Paint()
      ..color = themeColor.withOpacity(0.06)
      ..style = PaintingStyle.fill;

    const sweepAngle = math.pi * 0.35;
    final startAngle = (progress * 2 * math.pi) - (sweepAngle / 2);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius),
      startAngle,
      sweepAngle,
      true,
      sweepPaint,
    );

    // Range rings
    final ringPaint = Paint()
      ..color = themeColor.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, maxRadius * 0.35, ringPaint);
    canvas.drawCircle(center, maxRadius * 0.70, ringPaint);
  }

  @override
  bool shouldRepaint(covariant _CockpitRadarSweepPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// 3D Perspective Canvas Painter (Stitch Vector Reference)
class _TerrainPerspectivePainter extends CustomPainter {
  final double animationProgress;
  final double heading;

  _TerrainPerspectivePainter({
    required this.animationProgress,
    required this.heading,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.60);
    final horizonY = size.height * 0.20;

    final horizonPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF040812),
          AppColors.surfaceContainerLowest,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), horizonPaint);

    final gridPaint = Paint()
      ..color = AppColors.outlineVariant.withOpacity(0.15)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i <= 8; i++) {
      final y = horizonY + (size.height - horizonY) * math.pow(i / 8, 1.8);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    const numRadials = 10;
    for (int i = 0; i <= numRadials; i++) {
      final startX = size.width * (i / numRadials);
      canvas.drawLine(
        Offset(startX, size.height),
        Offset(center.dx + (startX - center.dx) * 0.15, horizonY),
        gridPaint,
      );
    }

    final contourPaint = Paint()
      ..color = AppColors.secondaryFixed.withOpacity(0.25)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (int c = 1; c <= 4; c++) {
      final path = Path();
      final baseY = horizonY + 50.0 * c;
      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 30) {
        final wave = math.sin(x * 0.02 + c) * 12 + math.cos(x * 0.01) * 8;
        path.lineTo(x, baseY + wave);
      }
      canvas.drawPath(path, contourPaint);
    }

    final routeGlowPaint = Paint()
      ..color = AppColors.primaryContainer.withOpacity(0.35)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;

    final routeCorePaint = Paint()
      ..color = AppColors.primaryContainer
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final routePath = Path();
    routePath.moveTo(center.dx - 15, size.height);
    routePath.quadraticBezierTo(
      center.dx + 40,
      size.height * 0.70,
      center.dx - 30,
      size.height * 0.45,
    );
    routePath.lineTo(center.dx - 50, size.height * 0.35);

    canvas.drawPath(routePath, routeGlowPaint);
    canvas.drawPath(routePath, routeCorePaint);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: FractionalOffset(center.dx / size.width, center.dy / size.height),
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          AppColors.primaryContainer.withOpacity(0.20),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25],
        transform: GradientRotation(animationProgress * 2 * math.pi),
      ).createShader(Rect.fromCircle(center: center, radius: 140));

    canvas.drawCircle(center, 130, sweepPaint);

    final userDotPaint = Paint()..color = AppColors.primaryContainer;
    canvas.drawCircle(center, 7, userDotPaint);

    final userRingPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 7, userRingPaint);
  }

  @override
  bool shouldRepaint(covariant _TerrainPerspectivePainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.heading != heading;
  }
}
