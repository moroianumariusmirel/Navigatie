import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../core/models/activity_type.dart';
import '../../core/models/route_model.dart';
import '../../core/maps/osm_tile_providers.dart';

class InteractiveRouteMap extends StatefulWidget {
  final RouteModel route;
  final ActivityType activityType;
  final double height;
  final bool isInteractive;

  const InteractiveRouteMap({
    super.key,
    required this.route,
    required this.activityType,
    this.height = 240,
    this.isInteractive = true,
  });

  @override
  State<InteractiveRouteMap> createState() => _InteractiveRouteMapState();
}

class _InteractiveRouteMapState extends State<InteractiveRouteMap> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  void _fitRouteBounds() {
    if (widget.route.coordinates.isEmpty) return;

    final bounds = LatLngBounds.fromPoints(widget.route.coordinates);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCycling = widget.activityType == ActivityType.cycling;
    final primaryTheme = isCycling ? AppColors.primaryContainer : AppColors.secondaryContainer;
    final initialCenter = widget.route.coordinates.isNotEmpty
        ? widget.route.coordinates.first
        : const LatLng(47.912, 7.898);

    final startPoint = widget.route.coordinates.isNotEmpty ? widget.route.coordinates.first : null;
    final endPoint = widget.route.coordinates.length > 1 ? widget.route.coordinates.last : null;

    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryTheme.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // FlutterMap Engine
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 12.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              interactionOptions: InteractionOptions(
                flags: widget.isInteractive ? InteractiveFlag.all : InteractiveFlag.none,
              ),
              onMapReady: () {
                _fitRouteBounds();
              },
            ),
            children: [
              // Dedicated Activity OSM Layer (Seamlessly switches to Vector PMTiles if region is downloaded)
              ListenableBuilder(
                listenable: OsmTileProviders.changeNotifier,
                builder: (context, _) => OsmTileProviders.layerForActivity(
                  widget.activityType,
                  center: widget.route.coordinates.isNotEmpty ? widget.route.coordinates.first : null,
                ),
              ),

              // Tactical Route Polyline (Double Layer: Outer Glow + Solid Core)
              if (widget.route.coordinates.isNotEmpty) ...[
                PolylineLayer(
                  polylines: [
                    // Outer neon glow
                    Polyline(
                      points: widget.route.coordinates,
                      strokeWidth: 8.0,
                      color: primaryTheme.withOpacity(0.35),
                    ),
                    // Core polyline
                    Polyline(
                      points: widget.route.coordinates,
                      strokeWidth: 4.0,
                      color: primaryTheme,
                    ),
                  ],
                ),
              ],

              // Waypoint & Terminal Markers
              MarkerLayer(
                markers: [
                  // Start Marker
                  if (startPoint != null)
                    Marker(
                      point: startPoint,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryContainer, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(Icons.trip_origin, color: AppColors.primaryContainer, size: 16),
                      ),
                    ),

                  // Finish Marker
                  if (endPoint != null)
                    Marker(
                      point: endPoint,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.secondaryFixed, width: 2),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                        child: const Icon(Icons.flag, color: AppColors.secondaryFixed, size: 16),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Tactical Map Style Indicator Badge (Top Left)
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest.withOpacity(0.92),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryTheme.withOpacity(0.5)),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 4),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCycling ? Icons.directions_bike : Icons.terrain,
                    size: 13,
                    color: primaryTheme,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    isCycling ? 'CYCLOSM • CYCLE TRACKS' : 'OPENTOPOMAP • TOPO CONTOURS',
                    style: AppTypography.microCaps.copyWith(
                      color: AppColors.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Controls (Top Right: Recenter & Zoom)
          if (widget.isInteractive)
            Positioned(
              top: 10,
              right: 10,
              child: Column(
                children: [
                  _MapControlButton(
                    icon: Icons.crop_free,
                    tooltip: 'Fit route',
                    onTap: _fitRouteBounds,
                  ),
                  const SizedBox(height: 6),
                  _MapControlButton(
                    icon: Icons.add,
                    tooltip: 'Zoom in',
                    onTap: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, currentZoom + 1);
                    },
                  ),
                  const SizedBox(height: 6),
                  _MapControlButton(
                    icon: Icons.remove,
                    tooltip: 'Zoom out',
                    onTap: () {
                      final currentZoom = _mapController.camera.zoom;
                      _mapController.move(_mapController.camera.center, currentZoom - 1);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest.withOpacity(0.90),
      borderRadius: BorderRadius.circular(8),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
      ),
    );
  }
}
