import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../core/telemetry/telemetry_service.dart';
import '../../core/models/activity_type.dart';
import '../../core/models/osm_gpx_trace.dart';
import '../../core/routing/osm_traces_service.dart';
import '../../core/offline/offline_tile_manager.dart';
import '../planner/widgets/route_loader_modal.dart';
import '../widgets/interactive_route_map.dart';

enum ExploreMode { online, offline }

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  ExploreMode _exploreMode = ExploreMode.online;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<OsmGpxTrace> _traces = [];
  bool _isLoadingTraces = false;

  @override
  void initState() {
    super.initState();
    _loadTraces();
  }

  Future<void> _loadTraces() async {
    setState(() {
      _isLoadingTraces = true;
    });

    final telemetry = Provider.of<TelemetryService>(context, listen: false);
    final results = await OsmTracesService.fetchTraces(
      activityType: telemetry.activityType,
      searchQuery: _searchQuery,
    );

    if (mounted) {
      setState(() {
        _traces = results;
        _isLoadingTraces = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showTracePreviewModal(BuildContext context, OsmGpxTrace trace, ActivityType activityType) {
    final routeModel = trace.toRouteModel();
    final isCycling = activityType == ActivityType.cycling;
    final primaryTheme = isCycling ? AppColors.primaryContainer : AppColors.secondaryContainer;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.outlineVariant, width: 1)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      trace.name,
                      style: AppTypography.headlineSm.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Uploader: ${trace.uploader} • Trackpoints: ${trace.trackpointCount}',
                style: AppTypography.microCaps.copyWith(color: AppColors.secondaryFixed),
              ),
              const SizedBox(height: 12),

              // Interactive Route Map
              Expanded(
                child: InteractiveRouteMap(
                  route: routeModel,
                  activityType: activityType,
                  height: double.infinity,
                ),
              ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ModalStat(label: 'DISTANCE', value: '${trace.distanceKm} km'),
                  _ModalStat(label: 'ASCENT', value: '+${trace.ascentM.toInt()}m'),
                  _ModalStat(label: 'MAX ELE', value: '${trace.maxElevationM.toInt()}m'),
                  _ModalStat(label: 'SCALE', value: trace.difficulty.split('•').first.trim()),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final telemetry = Provider.of<TelemetryService>(context, listen: false);
                    telemetry.updateActiveRoute(routeModel);
                    telemetry.saveRouteOffline(routeModel);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.surfaceContainerHighest,
                        content: Text(
                          'ACTIVATED FOR NAVIGATION: ${trace.name}',
                          style: AppTypography.bodySm.copyWith(color: primaryTheme),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.navigation, size: 18),
                  label: const Text('LOAD INTO COCKPIT HUD'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTheme,
                    foregroundColor: isCycling ? AppColors.onPrimary : AppColors.onSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = Provider.of<TelemetryService>(context);
    final isCycling = telemetry.activityType == ActivityType.cycling;
    final primaryTheme = isCycling ? AppColors.primaryContainer : AppColors.secondaryContainer;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Text(
              'EXPLORE & TRAILS',
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
                color: primaryTheme.withOpacity(0.2),
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. TOP CONTROLS: Activity Toggle (Left) + Load Route Button (Right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Activity Toggle (Cycling vs Hiking)
                _ExploreActivityToggle(
                  currentActivity: telemetry.activityType,
                  onChanged: (type) {
                    telemetry.setActivityType(type);
                    _loadTraces();
                  },
                ),

                // Load Route / GPX Button
                _ExploreLoadRouteButton(
                  onTap: () {
                    RouteLoaderModal.show(context, telemetry.activityType);
                  },
                ),
              ],
            ),

            const SizedBox(height: 14),

            // 2. ONLINE vs OFFLINE Segmented Switcher
            _OnlineOfflineSwitcher(
              currentMode: _exploreMode,
              primaryTheme: primaryTheme,
              onChanged: (mode) {
                setState(() {
                  _exploreMode = mode;
                });
              },
            ),

            const SizedBox(height: 16),

            // 3. CONTENT AREA: Online OSM Traces vs Offline Saved Routes
            if (_exploreMode == ExploreMode.online) ...[
              _buildOnlineTracesView(context, telemetry, primaryTheme, isCycling),
            ] else ...[
              _buildOfflineSavedView(context, telemetry, primaryTheme, isCycling),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// ONLINE VIEW: OpenStreetMap Public GPS Traces
  Widget _buildOnlineTracesView(
    BuildContext context,
    TelemetryService telemetry,
    Color primaryTheme,
    bool isCycling,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search & Filter Input
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
              _loadTraces();
            },
            style: const TextStyle(fontSize: 13, color: AppColors.primary),
            decoration: InputDecoration(
              hintText: isCycling
                  ? 'Search OSM cycling traces (e.g. gravel, Schauinsland, mtb)...'
                  : 'Search OSM hiking traces (e.g. Feldberg, cirque, ridge)...',
              hintStyle: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.onSurfaceVariant),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16, color: AppColors.onSurfaceVariant),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                        _loadTraces();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Live OSM Status Banner
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
                const SizedBox(width: 6),
                Text(
                  'OPENSTREETMAP PUBLIC TRACES (${_traces.length})',
                  style: AppTypography.microCaps.copyWith(
                    color: AppColors.secondaryFixed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (_isLoadingTraces)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryContainer),
              ),
          ],
        ),

        const SizedBox(height: 10),

        // Traces List
        if (_traces.isEmpty && !_isLoadingTraces)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Column(
              children: [
                const Icon(Icons.location_off, size: 36, color: AppColors.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(
                  'No public traces found for "$_searchQuery"',
                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          )
        else
          ..._traces.map((trace) {
            final isSaved = telemetry.savedOfflineRoutes.any((r) => r.id == trace.id);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSaved
                      ? AppColors.primaryContainer.withOpacity(0.4)
                      : AppColors.outlineVariant.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isCycling
                            ? AppColors.primaryContainer.withOpacity(0.15)
                            : AppColors.secondaryContainer.withOpacity(0.15),
                        child: Icon(
                          isCycling ? Icons.directions_bike : Icons.hiking,
                          color: primaryTheme,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trace.name,
                              style: AppTypography.headlineSm.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Mapper: ${trace.uploader} • Uploaded ${trace.uploadedAt}',
                              style: AppTypography.microCaps.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Text(
                    trace.description,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.3,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Stats Grid
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _TraceStat(label: 'DIST', value: '${trace.distanceKm} km'),
                      _TraceStat(label: 'ASCENT', value: '+${trace.ascentM.toInt()}m'),
                      _TraceStat(label: 'DESCENT', value: '-${trace.descentM.toInt()}m'),
                      _TraceStat(label: 'PEAK', value: '${trace.maxElevationM.toInt()}m'),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Tag Chips
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: trace.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBright,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: AppTypography.microCaps.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 9,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 14),

                  // Actions Row
                  Row(
                    children: [
                      // Preview Button
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showTracePreviewModal(context, trace, telemetry.activityType),
                          icon: const Icon(Icons.map, size: 14),
                          label: const Text('PREVIEW'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.outlineVariant),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Download / Save Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isSaved
                              ? null
                              : () {
                                  telemetry.saveRouteOffline(trace.toRouteModel());
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.surfaceContainerHighest,
                                      content: Text(
                                        'SAVED TO OFFLINE: ${trace.name}',
                                        style: AppTypography.bodySm.copyWith(color: AppColors.secondaryFixed),
                                      ),
                                    ),
                                  );
                                },
                          icon: Icon(
                            isSaved ? Icons.check : Icons.download_for_offline,
                            size: 14,
                          ),
                          label: Text(isSaved ? 'SAVED' : 'SAVE OFFLINE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSaved
                                ? AppColors.surfaceBright
                                : primaryTheme.withOpacity(0.2),
                            foregroundColor: isSaved
                                ? AppColors.secondaryFixed
                                : primaryTheme,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  /// OFFLINE VIEW: Downloaded Routes & Map Regions
  Widget _buildOfflineSavedView(
    BuildContext context,
    TelemetryService telemetry,
    Color primaryTheme,
    bool isCycling,
  ) {
    final savedRoutes = telemetry.savedOfflineRoutes;
    final regions = OfflineTileManager.sampleRegions();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header: Saved Routes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SAVED ROUTES & IMPORTED GPX (${savedRoutes.length})',
              style: AppTypography.labelCaps.copyWith(
                color: AppColors.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.secondaryFixed.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '100% OFFLINE READY',
                style: AppTypography.microCaps.copyWith(
                  color: AppColors.secondaryFixed,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (savedRoutes.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                'No routes saved yet.\nDownload public traces in the Online tab or import a GPX file.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          )
        else
          ...savedRoutes.map((route) {
            final isCurrentActive = telemetry.activeRoute?.id == route.id;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrentActive
                      ? primaryTheme
                      : AppColors.outlineVariant.withOpacity(0.2),
                  width: isCurrentActive ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        route.activityType == ActivityType.cycling
                            ? Icons.directions_bike
                            : Icons.hiking,
                        color: route.activityType == ActivityType.cycling
                            ? AppColors.primaryContainer
                            : AppColors.secondaryContainer,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          route.name,
                          style: AppTypography.bodyMd.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isCurrentActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: primaryTheme,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ACTIVE HUD',
                            style: AppTypography.microCaps.copyWith(
                              color: isCycling ? AppColors.onPrimary : AppColors.onSecondary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${route.totalDistanceKm} km • +${route.totalAscentM.toInt()}m ascent',
                        style: AppTypography.microCaps.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      Text(
                        route.difficultyRating,
                        style: AppTypography.microCaps.copyWith(color: primaryTheme),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            telemetry.updateActiveRoute(route);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.surfaceContainerHighest,
                                content: Text('Loaded ${route.name} into Cockpit HUD!'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.play_arrow, size: 14),
                          label: Text(isCurrentActive ? 'LOADED IN COCKPIT' : 'ACTIVATE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCurrentActive
                                ? AppColors.surfaceBright
                                : primaryTheme.withOpacity(0.2),
                            foregroundColor: isCurrentActive
                                ? AppColors.primary
                                : primaryTheme,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.onSurfaceVariant),
                        tooltip: 'Delete offline copy',
                        onPressed: () {
                          telemetry.removeOfflineRoute(route.id);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 20),

        // Section Header: Offline Regional Map Packages
        Text(
          'REGIONAL OFFLINE MAP PACKAGES',
          style: AppTypography.labelCaps.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),

        ...regions.map((region) {
          final isReady = region.state == RegionDownloadState.ready;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isReady
                    ? AppColors.primaryContainer.withOpacity(0.5)
                    : AppColors.outlineVariant.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isReady ? Icons.check_circle : Icons.cloud_download_outlined,
                  color: isReady ? AppColors.primaryContainer : AppColors.secondaryFixed,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        region.name,
                        style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        region.description,
                        style: AppTypography.microCaps.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isReady ? AppColors.primaryContainer : AppColors.surfaceBright,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isReady ? 'DOWNLOADED' : '${region.sizeMb} MB',
                    style: AppTypography.microCaps.copyWith(
                      color: isReady ? AppColors.onPrimaryContainer : AppColors.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

/// Activity Toggle (Cycling vs Hiking) matching PlannerScreen
class _ExploreActivityToggle extends StatelessWidget {
  final ActivityType currentActivity;
  final ValueChanged<ActivityType> onChanged;

  const _ExploreActivityToggle({
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

/// Load Route Button matching PlannerScreen
class _ExploreLoadRouteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ExploreLoadRouteButton({required this.onTap});

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

/// Segmented Switcher for Online OSM Traces vs Offline Saved
class _OnlineOfflineSwitcher extends StatelessWidget {
  final ExploreMode currentMode;
  final Color primaryTheme;
  final ValueChanged<ExploreMode> onChanged;

  const _OnlineOfflineSwitcher({
    required this.currentMode,
    required this.primaryTheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = currentMode == ExploreMode.online;

    return Container(
      width: double.infinity,
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(ExploreMode.online),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: isOnline ? primaryTheme.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: isOnline ? Border.all(color: primaryTheme.withOpacity(0.6)) : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.public,
                      size: 15,
                      color: isOnline ? primaryTheme : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'ONLINE OSM TRACES',
                      style: AppTypography.labelCaps.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isOnline ? primaryTheme : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(ExploreMode.offline),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: !isOnline ? AppColors.secondaryFixed.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: !isOnline ? Border.all(color: AppColors.secondaryFixed.withOpacity(0.6)) : null,
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.download_done,
                      size: 15,
                      color: !isOnline ? AppColors.secondaryFixed : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'OFFLINE SAVED',
                      style: AppTypography.labelCaps.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: !isOnline ? AppColors.secondaryFixed : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TraceStat extends StatelessWidget {
  final String label;
  final String value;

  const _TraceStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.microCaps),
        const SizedBox(height: 1),
        Text(
          value,
          style: AppTypography.dataMetricMd.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ModalStat extends StatelessWidget {
  final String label;
  final String value;

  const _ModalStat({required this.label, required this.value});

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
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
