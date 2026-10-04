import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../core/telemetry/telemetry_service.dart';
import '../../core/models/activity_type.dart';
import '../../core/models/explore_mode.dart';
import '../../core/models/route_model.dart';
import '../../core/models/waypoint_model.dart';
import '../../core/maps/osm_tile_providers.dart';
import '../../core/routing/osm_routing_service.dart';
import 'widgets/route_loader_modal.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final MapController _mapController = MapController();
  final List<LatLng> _plannedPoints = [];
  RouteModel? _customRoute;
  bool _isCalculating = false;
  String? _errorMessage;
  bool _hasAutoCentered = false;
  bool _hasDismissedLoadedRoute = false;

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _hasDismissedLoadedRoute = false;
      if (_plannedPoints.isEmpty) {
        // Point 1: Start Point (A)
        _plannedPoints.add(point);
      } else if (_plannedPoints.length == 1) {
        // Point 2: Arrival Point (B) -> Trigger route calculation
        _plannedPoints.add(point);
        _recalculateRoute();
      } else {
        // Point 3+: Insert intermediate stop waypoint right before arrival point
        _plannedPoints.insert(_plannedPoints.length - 1, point);
        _recalculateRoute();
      }
    });
  }

  Future<void> _recalculateRoute([ActivityType? overrideActivity]) async {
    if (_plannedPoints.length < 2) {
      setState(() {
        _customRoute = null;
      });
      return;
    }

    setState(() {
      _isCalculating = true;
      _errorMessage = null;
    });

    try {
      final telemetry = Provider.of<TelemetryService>(context, listen: false);
      final activity = overrideActivity ?? telemetry.activityType;
      final routeName = _customRoute?.name ??
          (activity == ActivityType.cycling
              ? 'Custom Cycling Route'
              : 'Custom Hiking Ridge Trail');

      final route = await OsmRoutingService.calculateRoute(
        points: List<LatLng>.from(_plannedPoints),
        activityType: activity,
        customName: routeName,
      );

      if (mounted) {
        setState(() {
          _customRoute = route;
          _isCalculating = false;
        });

        // Fit camera to newly calculated route
        if (route.coordinates.isNotEmpty) {
          _fitRouteBounds(route.coordinates);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Calculation failed: $e';
          _isCalculating = false;
        });
      }
    }
  }

  void _removePoint(int index) {
    setState(() {
      if (index >= 0 && index < _plannedPoints.length) {
        _plannedPoints.removeAt(index);
        if (_plannedPoints.length < 2) {
          _customRoute = null;
        } else {
          _recalculateRoute();
        }
      }
    });
  }

  void _undoLastPoint() {
    if (_plannedPoints.isNotEmpty) {
      _removePoint(_plannedPoints.length - 1);
    }
  }

  void _resetPlannerMapRoute() {
    setState(() {
      _plannedPoints.clear();
      _customRoute = null;
      _hasDismissedLoadedRoute = true;
      _errorMessage = null;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PLANNER MAP RESET • ROUTE REMOVED'),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.surfaceContainerHigh,
      ),
    );
  }

  void _reverseRoute() {
    if (_plannedPoints.length >= 2) {
      setState(() {
        final reversed = _plannedPoints.reversed.toList();
        _plannedPoints
          ..clear()
          ..addAll(reversed);
      });
      _recalculateRoute();
    }
  }

  void _fitRouteBounds(List<LatLng> coords) {
    if (coords.isEmpty) return;
    try {
      final bounds = LatLngBounds.fromPoints(coords);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(36),
        ),
      );
    } catch (_) {}
  }

  void _saveRoute(RouteModel route) {
    final telemetry = Provider.of<TelemetryService>(context, listen: false);
    final isCycling = telemetry.activityType == ActivityType.cycling;
    final primaryTheme = isCycling ? AppColors.primaryContainer : AppColors.secondaryContainer;
    final nameController = TextEditingController(text: route.name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHigh,
        title: Text(
          'SAVE ROUTE OFFLINE',
          style: AppTypography.headlineSm.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a descriptive name for this tactical route. It will be stored in your offline library and available under "Offline Saved" in Explorer:',
              style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              autofocus: true,
              style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceContainerLowest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: primaryTheme),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'CANCEL',
              style: AppTypography.labelCaps.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryTheme,
              foregroundColor: isCycling ? AppColors.onPrimary : AppColors.onSecondary,
            ),
            onPressed: () {
              final newName = nameController.text.trim();
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final isSample = route.id.isEmpty ||
                  route.id.startsWith('schauinsland_') ||
                  route.id.startsWith('feldberg_') ||
                  route.id.startsWith('sample_');
              final routeId = isSample ? 'saved_plan_$timestamp' : route.id;

              final saved = route.copyWith(
                id: routeId,
                name: newName.isNotEmpty ? newName : route.name,
              );

              // 1. Save to offline library (prepends to offline routes)
              telemetry.saveRouteOffline(saved);

              // 2. Set Explorer mode to offline so it opens directly in "OFFLINE SAVED"
              telemetry.setExploreMode(ExploreMode.offline);

              Navigator.of(ctx).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.surfaceContainerHighest,
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.only(bottom: 96, left: 12, right: 12),
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'VIEW IN ROUTES',
                    textColor: primaryTheme,
                    onPressed: () {
                      telemetry.setSelectedTabIndex(0); // Index 0 is Routes page
                    },
                  ),
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.primaryContainer, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Route "${saved.name}" saved to Offline Library in Explorer!',
                          style: AppTypography.bodySm.copyWith(color: AppColors.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Text(
              'SAVE',
              style: AppTypography.labelCaps.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  void _startNavigationInCockpit(RouteModel route) {
    final telemetry = Provider.of<TelemetryService>(context, listen: false);
    telemetry.startNavigation(route: route);
    telemetry.setSelectedTabIndex(2); // Index 2 is Cockpit

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceContainerHighest,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 96, left: 12, right: 12),
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            const Icon(Icons.navigation, color: AppColors.primaryContainer, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'TACTICAL ROUTE ENGAGED • COCKPIT HUD ONLINE',
                style: AppTypography.labelCaps.copyWith(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = Provider.of<TelemetryService>(context);
    final isCycling = telemetry.activityType == ActivityType.cycling;
    final primaryTheme = isCycling ? AppColors.primaryContainer : AppColors.secondaryContainer;
    final userGps = telemetry.userLocation;

    if (!_hasAutoCentered && userGps != null && _plannedPoints.isEmpty && _customRoute == null) {
      _hasAutoCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(userGps, 14.5);
      });
    }

    final fallbackRoute = _hasDismissedLoadedRoute ? null : telemetry.activeRoute;
    final displayRoute = _hasDismissedLoadedRoute
        ? null
        : (_customRoute ??
            fallbackRoute ??
            (isCycling ? RouteModel.sampleSchauinsland() : RouteModel.sampleFeldbergHike()));

    final coordinates = _customRoute != null
        ? _customRoute!.coordinates
        : (_plannedPoints.length >= 2
            ? _plannedPoints
            : (!_hasDismissedLoadedRoute && telemetry.activeRoute != null
                ? telemetry.activeRoute!.coordinates
                : const <LatLng>[]));

    final bool hasLoadedRoute = !_hasDismissedLoadedRoute &&
        (_customRoute != null || _plannedPoints.isNotEmpty || coordinates.isNotEmpty || (displayRoute != null && displayRoute.coordinates.isNotEmpty));

    final initialCenter = coordinates.isNotEmpty
        ? coordinates.first
        : (userGps ?? const LatLng(47.912, 7.898));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'ROUTE PLANNER',
              style: AppTypography.headlineSm.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isCycling
                    ? AppColors.primaryContainer.withOpacity(0.2)
                    : AppColors.secondaryContainer.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isCycling ? 'CYCLING' : 'HIKING',
                style: AppTypography.microCaps.copyWith(
                  color: isCycling ? AppColors.primaryContainer : AppColors.secondaryFixed,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (hasLoadedRoute)
            IconButton(
              icon: const Icon(Icons.restart_alt, color: AppColors.error),
              tooltip: 'Reset map route',
              onPressed: _resetPlannerMapRoute,
            ),
        ],
      ),
      body: Stack(
        children: [
          // ==========================================
          // 1. Fullscreen Interactive OpenStreetMap Viewport
          // ==========================================
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 13.5,
                minZoom: 4.0,
                maxZoom: 18.0,
                onTap: _onMapTap,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
              ),
              children: [
                // OpenStreetMap Activity Tile Layer (Seamlessly switches to Vector PMTiles if region is downloaded)
                OsmTileProviders.layerForActivity(
                  telemetry.activityType,
                  center: initialCenter,
                ),

                // Route Polyline (Double Layer: Outer Glow + Solid Core)
                if (coordinates.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: coordinates,
                        strokeWidth: 8.0,
                        color: primaryTheme.withOpacity(0.35),
                      ),
                      Polyline(
                        points: coordinates,
                        strokeWidth: 4.0,
                        color: primaryTheme,
                      ),
                    ],
                  ),

                // Waypoint / Stop Markers and Live User Beacon
                MarkerLayer(
                  markers: _buildMapMarkers(primaryTheme, coordinates, userGps),
                ),
              ],
            ),
          ),

          // ==========================================
          // 2. Top Controls Overlay: Activity Toggle + Load GPX / Reset
          // ==========================================
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ActivityToggle(
                  currentActivity: telemetry.activityType,
                  onChanged: (type) {
                    telemetry.setActivityType(type);
                    if (_plannedPoints.length >= 2) {
                      _recalculateRoute(type);
                    }
                  },
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasLoadedRoute) ...[
                      _ResetRouteButton(
                        onTap: _resetPlannerMapRoute,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _LoadRouteButton(
                      onTap: () async {
                        final loadedRoute = await RouteLoaderModal.show(context, telemetry.activityType);
                        if (loadedRoute != null && mounted) {
                          setState(() {
                            _plannedPoints.clear();
                            _customRoute = loadedRoute;
                            _hasDismissedLoadedRoute = false;
                          });
                          if (loadedRoute.coordinates.isNotEmpty) {
                            _fitRouteBounds(loadedRoute.coordinates);
                          }
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ==========================================
          // 3. Guidance HUD Status Banner (Below Top Controls)
          // ==========================================
          Positioned(
            top: 56,
            left: 12,
            right: 12,
            child: _buildGuidanceBanner(primaryTheme, userGps, hasLoadedRoute),
          ),

          // ==========================================
          // 4. Floating Map Controls (Bottom Right, above bottom dock)
          // ==========================================
          Positioned(
            bottom: 120,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapQuickActionBtn(
                  icon: Icons.my_location,
                  tooltip: 'Center on my location',
                  iconColor: AppColors.primaryContainer,
                  onTap: () {
                    final loc = telemetry.userLocation;
                    if (loc != null) {
                      _mapController.move(loc, 15.0);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Acquiring GPS location...'),
                          duration: Duration(seconds: 2),
                          backgroundColor: AppColors.surfaceContainerHigh,
                        ),
                      );
                    }
                  },
                ),
                if (hasLoadedRoute) ...[
                  _MapQuickActionBtn(
                    icon: Icons.restart_alt,
                    tooltip: 'Reset map route',
                    iconColor: AppColors.error,
                    onTap: _resetPlannerMapRoute,
                  ),
                  const SizedBox(height: 6),
                ],
                if (_plannedPoints.isNotEmpty) ...[
                  _MapQuickActionBtn(
                    icon: Icons.undo,
                    tooltip: 'Undo last point',
                    onTap: _undoLastPoint,
                  ),
                  const SizedBox(height: 6),
                ],
                if (coordinates.isNotEmpty) ...[
                  _MapQuickActionBtn(
                    icon: Icons.center_focus_strong,
                    tooltip: 'Fit route bounds',
                    onTap: () => _fitRouteBounds(coordinates),
                  ),
                  const SizedBox(height: 6),
                ],
                _MapQuickActionBtn(
                  icon: Icons.add,
                  tooltip: 'Zoom in',
                  onTap: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                ),
                const SizedBox(height: 6),
                _MapQuickActionBtn(
                  icon: Icons.remove,
                  tooltip: 'Zoom out',
                  onTap: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                ),
              ],
            ),
          ),

          // ==========================================
          // 5. Layer Label Badge (Bottom Left, above bottom dock)
          // ==========================================
          Positioned(
            bottom: 120,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest.withOpacity(0.90),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: primaryTheme.withOpacity(0.4)),
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

          // ==========================================
          // 6. Floating Bottom Action Dock: [START IN COCKPIT] & [SAVE ROUTE] or Empty Planning Prompt
          // ==========================================
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: displayRoute == null || !hasLoadedRoute
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.touch_app, size: 20, color: primaryTheme),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'MAP READY FOR ROUTE PLANNING',
                                style: AppTypography.labelCaps.copyWith(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap map to set Start (A) & Destination (B)',
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainerHigh,
                            foregroundColor: primaryTheme,
                            side: BorderSide(color: primaryTheme.withOpacity(0.6)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            final loadedRoute = await RouteLoaderModal.show(context, telemetry.activityType);
                            if (loadedRoute != null && mounted) {
                              setState(() {
                                _plannedPoints.clear();
                                _customRoute = loadedRoute;
                                _hasDismissedLoadedRoute = false;
                              });
                              if (loadedRoute.coordinates.isNotEmpty) {
                                _fitRouteBounds(loadedRoute.coordinates);
                              }
                            }
                          },
                          icon: const Icon(Icons.file_upload_outlined, size: 15),
                          label: Text(
                            'LOAD GPX',
                            style: AppTypography.microCaps.copyWith(
                              fontWeight: FontWeight.w900,
                              color: primaryTheme,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.45),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Compact metrics strip and Details trigger if route exists
                        if (displayRoute.coordinates.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Icon(Icons.route, size: 14, color: primaryTheme),
                                const SizedBox(width: 6),
                                Text(
                                  '${displayRoute.totalDistanceKm.toStringAsFixed(1)} km',
                                  style: AppTypography.bodySm.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('•', style: TextStyle(color: AppColors.onSurfaceVariant)),
                                const SizedBox(width: 8),
                                const Icon(Icons.trending_up, size: 14, color: AppColors.secondaryFixed),
                                const SizedBox(width: 4),
                                Text(
                                  '+${displayRoute.totalAscentM.toInt()}m',
                                  style: AppTypography.bodySm.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                                const Spacer(),
                                InkWell(
                                  onTap: () => _showRouteDetailsModal(context, displayRoute, isCycling, primaryTheme),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'DETAILS',
                                          style: AppTypography.microCaps.copyWith(
                                            color: primaryTheme,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(Icons.keyboard_arrow_up, size: 16, color: primaryTheme),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Pinned Primary Buttons: [START IN COCKPIT] & [SAVE ROUTE]
                        Row(
                          children: [
                            // Start Navigation in Cockpit Button
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryTheme,
                                  foregroundColor: isCycling ? AppColors.onPrimary : AppColors.onSecondary,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _startNavigationInCockpit(displayRoute),
                                icon: const Icon(Icons.rocket_launch, size: 18),
                                label: Text(
                                  'START IN COCKPIT',
                                  style: AppTypography.labelCaps.copyWith(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 0.8,
                                    color: isCycling ? AppColors.onPrimary : AppColors.onSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Save Route Button
                            Expanded(
                              flex: 2,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: AppColors.surfaceContainerHigh,
                                  foregroundColor: AppColors.secondaryFixed,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  side: BorderSide(color: AppColors.outlineVariant.withOpacity(0.5)),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _saveRoute(displayRoute),
                                icon: const Icon(Icons.save_outlined, size: 18),
                                label: Text(
                                  'SAVE ROUTE',
                                  style: AppTypography.labelCaps.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    color: AppColors.secondaryFixed,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Opens an expandable modal bottom sheet with route details, waypoints, stops, and surface breakdown
  void _showRouteDetailsModal(
    BuildContext context,
    RouteModel route,
    bool isCycling,
    Color primaryTheme,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: AppColors.outlineVariant, width: 1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: ListView(
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ROUTE DETAILS & WAYPOINTS',
                        style: AppTypography.headlineSm.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: primaryTheme,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20, color: AppColors.onSurfaceVariant),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildStopsManagerCard(route, isCycling, primaryTheme),
                  const SizedBox(height: 14),
                  _MainRouteOverviewCard(route: route, isCycling: isCycling),
                  const SizedBox(height: 14),
                  _SurfaceBreakdownCard(route: route, isCycling: isCycling),
                  const SizedBox(height: 14),
                  _TacticalAdvisoryCard(isCycling: isCycling),
                  const SizedBox(height: 14),
                  _WaypointsSection(waypoints: route.waypoints),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Builds guidance banner providing step-by-step cues for map clicks
  Widget _buildGuidanceBanner(Color primaryTheme, LatLng? userGps, bool hasLoadedRoute) {
    String text;
    IconData icon;
    Color iconColor;

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withOpacity(0.95),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.error, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 16, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _errorMessage!,
                style: AppTypography.labelCaps.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.error,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _errorMessage = null),
              child: const Icon(Icons.close, size: 16, color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    if (_isCalculating) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withOpacity(0.95),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primaryTheme, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: primaryTheme),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'CALCULATING ROUTE VIA OPENSTREETMAP...',
                style: AppTypography.labelCaps.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: primaryTheme,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_plannedPoints.isEmpty) {
      text = userGps != null ? 'TAP MAP OR "USE GPS" FOR START (A)' : 'STEP 1: TAP MAP TO SET START POINT (A)';
      icon = Icons.touch_app;
      iconColor = AppColors.primaryContainer;
    } else if (_plannedPoints.length == 1) {
      text = 'STEP 2: TAP MAP TO SET ARRIVAL POINT (B)';
      icon = Icons.flag_outlined;
      iconColor = AppColors.secondaryFixed;
    } else {
      text = 'ROUTE ACTIVE • TAP TO ADD STOPS (${_plannedPoints.length - 2} STOPS)';
      icon = Icons.add_location_alt;
      iconColor = Colors.amberAccent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withOpacity(0.92),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: primaryTheme.withOpacity(0.6), width: 1),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: AppTypography.labelCaps.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
              ),
            ),
          ),
          if (_plannedPoints.isEmpty && userGps != null) ...[
            GestureDetector(
              onTap: () {
                setState(() {
                  _hasDismissedLoadedRoute = false;
                  _plannedPoints.add(userGps);
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryTheme.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: primaryTheme),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.my_location, size: 12, color: primaryTheme),
                    const SizedBox(width: 4),
                    Text(
                      'USE GPS (A)',
                      style: AppTypography.microCaps.copyWith(
                        color: primaryTheme,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (hasLoadedRoute) const SizedBox(width: 6),
          ],
          if (hasLoadedRoute)
            GestureDetector(
              onTap: _resetPlannerMapRoute,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'RESET',
                  style: AppTypography.microCaps.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Builds map markers for Start (A), Stops (1..N-2), Arrival (B), and Live User Beacon
  List<Marker> _buildMapMarkers(Color primaryTheme, List<LatLng> coordinates, LatLng? userGps) {
    final markers = <Marker>[];

    // 1. Live User GPS Beacon
    if (userGps != null) {
      markers.add(
        Marker(
          point: userGps,
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer.withOpacity(0.22),
                  border: Border.all(
                    color: AppColors.primaryContainer.withOpacity(0.65),
                    width: 1.5,
                  ),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1)),
                  ],
                ),
              ),
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_plannedPoints.isNotEmpty) {
      for (int i = 0; i < _plannedPoints.length; i++) {
        final pt = _plannedPoints[i];
        final isStart = i == 0;
        final isEnd = i == _plannedPoints.length - 1 && _plannedPoints.length > 1;

        final badgeColor = isStart
            ? AppColors.primaryContainer
            : isEnd
                ? AppColors.secondaryFixed
                : Colors.amberAccent;

        final label = isStart
            ? 'A'
            : isEnd
                ? 'B'
                : '$i';

        markers.add(
          Marker(
            point: pt,
            width: 32,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2)),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } else if (coordinates.isNotEmpty) {
      markers.add(
        Marker(
          point: coordinates.first,
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryContainer, width: 2.5),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
            ),
            child: const Center(
              child: Text(
                'A',
                style: TextStyle(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      );

      if (coordinates.length > 1) {
        markers.add(
          Marker(
            point: coordinates.last,
            width: 32,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.secondaryFixed, width: 2.5),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
              ),
              child: const Center(
                child: Text(
                  'B',
                  style: TextStyle(
                    color: AppColors.secondaryFixed,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  /// Interactive stops and waypoints manager in the bottom 40% panel
  Widget _buildStopsManagerCard(RouteModel displayRoute, bool isCycling, Color primaryTheme) {
    if (_plannedPoints.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryTheme.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_location_alt, color: primaryTheme, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CUSTOM ROUTE BUILDER',
                    style: AppTypography.labelCaps.copyWith(
                      fontWeight: FontWeight.w900,
                      color: primaryTheme,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tap anywhere on the map above to set Start (A) & Arrival (B) points.',
                    style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ROUTE STOPS & WAYPOINTS (${_plannedPoints.length})',
                style: AppTypography.labelCaps.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              if (_plannedPoints.length >= 2)
                InkWell(
                  onTap: _reverseRoute,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_vert, size: 15, color: AppColors.primaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        'REVERSE',
                        style: AppTypography.microCaps.copyWith(
                          color: AppColors.primaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(_plannedPoints.length, (idx) {
            final pt = _plannedPoints[idx];
            final isStart = idx == 0;
            final isEnd = idx == _plannedPoints.length - 1 && _plannedPoints.length > 1;

            final badgeColor = isStart
                ? AppColors.primaryContainer
                : isEnd
                    ? AppColors.secondaryFixed
                    : Colors.amberAccent;

            final title = isStart
                ? 'Start Point (A)'
                : isEnd
                    ? 'Arrival Destination (B)'
                    : 'Stop Waypoint $idx';

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        isStart ? 'A' : isEnd ? 'B' : '$idx',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${pt.latitude.toStringAsFixed(4)}, ${pt.longitude.toStringAsFixed(4)}',
                          style: AppTypography.microCaps.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.error),
                    tooltip: 'Remove point',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _removePoint(idx),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Floating square tactical button for map controls
class _MapQuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? iconColor;

  const _MapQuickActionBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest.withOpacity(0.92),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.4)),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
          ),
          child: Icon(icon, size: 18, color: iconColor ?? AppColors.onSurface),
        ),
      ),
    );
  }
}

/// Tactical Segmented Switch for Activity Selection (Cycling vs Hiking)
class _ActivityToggle extends StatelessWidget {
  final ActivityType currentActivity;
  final ValueChanged<ActivityType> onChanged;

  const _ActivityToggle({
    required this.currentActivity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isCycling = currentActivity == ActivityType.cycling;

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cycling Option
          GestureDetector(
            onTap: () => onChanged(ActivityType.cycling),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isCycling ? AppColors.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isCycling
                    ? [
                        BoxShadow(
                          color: AppColors.primaryContainer.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.directions_bike,
                    size: 15,
                    color: isCycling ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'CYCLING',
                    style: AppTypography.labelCaps.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isCycling ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Hiking Option
          GestureDetector(
            onTap: () => onChanged(ActivityType.hiking),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: !isCycling ? AppColors.secondaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: !isCycling
                    ? [
                        BoxShadow(
                          color: AppColors.secondaryContainer.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        )
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.hiking,
                    size: 15,
                    color: !isCycling ? AppColors.onSecondary : AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'HIKING',
                    style: AppTypography.labelCaps.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: !isCycling ? AppColors.onSecondary : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tactical Reset Route Button to remove currently loaded map route on Planner
class _ResetRouteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ResetRouteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.error.withOpacity(0.6),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restart_alt, size: 16, color: AppColors.error),
            const SizedBox(width: 5),
            Text(
              'RESET',
              style: AppTypography.labelCaps.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tactical Load Route Button with format badges
class _LoadRouteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _LoadRouteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.secondaryFixed.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.file_upload_outlined, size: 16, color: AppColors.secondaryFixed),
            const SizedBox(width: 6),
            Text(
              'LOAD GPX',
              style: AppTypography.labelCaps.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.secondaryFixed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overview Card adapting data based on activity
class _MainRouteOverviewCard extends StatelessWidget {
  final RouteModel route;
  final bool isCycling;

  const _MainRouteOverviewCard({required this.route, required this.isCycling});

  @override
  Widget build(BuildContext context) {
    final themeColor = isCycling ? AppColors.primaryContainer : AppColors.secondaryContainer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: themeColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isCycling ? 'GRAVEL / MTB / ROAD' : 'ALPINE TREK / HIKING',
                  style: AppTypography.microCaps.copyWith(
                    color: isCycling ? AppColors.primaryContainer : AppColors.secondaryFixed,
                    fontWeight: FontWeight.w800,
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
                      color: AppColors.secondaryFixed,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'OFFLINE READY',
                    style: AppTypography.microCaps.copyWith(
                      color: AppColors.secondaryFixed,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            route.name,
            style: AppTypography.headlineSm.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'EST. TIME: ${route.estimatedDuration}',
                style: AppTypography.labelCaps.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
              const SizedBox(width: 14),
              const Icon(Icons.terrain, size: 14, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  route.difficultyRating,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelCaps.copyWith(
                    color: isCycling ? AppColors.primaryContainer : AppColors.secondaryFixed,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatColumn(label: 'DISTANCE', value: '${route.totalDistanceKm} km'),
              _StatColumn(label: 'ASCENT', value: '+${route.totalAscentM.toInt()}m'),
              _StatColumn(label: 'DESCENT', value: '-${route.totalDescentM.toInt()}m'),
              _StatColumn(label: 'MAX ELE', value: '${route.maxElevationM.toInt()}m'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Surface & Footing breakdown adapting to cycling vs hiking
class _SurfaceBreakdownCard extends StatelessWidget {
  final RouteModel route;
  final bool isCycling;

  const _SurfaceBreakdownCard({required this.route, required this.isCycling});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isCycling ? 'TRAIL SURFACE BREAKDOWN' : 'FOOTING & TERRAIN BREAKDOWN',
          style: AppTypography.labelCaps.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Segmented Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: _buildSegmentedBars(route.surfaceBreakdown),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              ...route.surfaceBreakdown.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: AppTypography.bodyMd),
                      Text(
                        '${(entry.value * 100).toInt()}%',
                        style: AppTypography.labelCaps.copyWith(
                          color: isCycling ? AppColors.primaryContainer : AppColors.secondaryFixed,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSegmentedBars(Map<String, double> breakdown) {
    final colors = [
      AppColors.primaryContainer,
      AppColors.secondaryContainer,
      AppColors.surfaceBright,
      AppColors.tertiaryContainer,
    ];

    int idx = 0;
    return breakdown.values.map((val) {
      final flex = mathMax(1, (val * 100).round());
      final color = colors[idx % colors.length];
      idx++;
      return Expanded(
        flex: flex,
        child: Container(color: color),
      );
    }).toList();
  }

  int mathMax(int a, int b) => a > b ? a : b;
}

/// Tactical Advisory specific to cycling vs hiking
class _TacticalAdvisoryCard extends StatelessWidget {
  final bool isCycling;

  const _TacticalAdvisoryCard({required this.isCycling});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isCycling ? AppColors.primaryContainer : AppColors.secondaryContainer).withOpacity(0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isCycling ? Icons.tune : Icons.hiking,
            color: isCycling ? AppColors.primaryContainer : AppColors.secondaryFixed,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCycling ? 'CYCLING GEAR & TACTICAL ADVISORY' : 'HIKING GEAR & ALPINE SAFETY',
                  style: AppTypography.microCaps.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isCycling ? AppColors.primaryContainer : AppColors.secondaryFixed,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isCycling
                      ? 'Recommended tire pressure: 28-32 PSI. Steep apex at KM 35 (+16%). Keep 40% battery reserve for night descent.'
                      : 'Sturdy ankle boots recommended for scree sections. Mountain weather warning: High winds expected at summit ridge after 15:00.',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurface,
                    height: 1.3,
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

/// Waypoints Section
class _WaypointsSection extends StatelessWidget {
  final List<WaypointModel> waypoints;

  const _WaypointsSection({required this.waypoints});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PLANNED WAYPOINTS (${waypoints.length})',
          style: AppTypography.labelCaps.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        ...waypoints.map((wpt) => _WaypointItemTile(waypoint: wpt)),
      ],
    );
  }
}

class _WaypointItemTile extends StatelessWidget {
  final WaypointModel waypoint;

  const _WaypointItemTile({required this.waypoint});

  @override
  Widget build(BuildContext context) {
    final isApex = waypoint.isApex;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: isApex ? Border.all(color: AppColors.errorContainer) : null,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: isApex ? AppColors.error : AppColors.surfaceBright,
            child: Text(
              '${waypoint.index}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isApex ? AppColors.onError : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  waypoint.title,
                  style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w700),
                ),
                if (waypoint.description != null)
                  Text(
                    waypoint.description!,
                    style: AppTypography.microCaps.copyWith(color: AppColors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                waypoint.elevation,
                style: AppTypography.dataMetricMd.copyWith(
                  fontSize: 13,
                  color: isApex ? AppColors.error : AppColors.primary,
                ),
              ),
              Text(waypoint.distance, style: AppTypography.microCaps),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;

  const _StatColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.microCaps),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.dataMetricMd.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}
