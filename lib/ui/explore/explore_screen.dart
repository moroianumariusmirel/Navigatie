import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../core/telemetry/telemetry_service.dart';
import '../../core/models/activity_type.dart';
import '../../core/models/route_model.dart';
import '../planner/widgets/route_loader_modal.dart';
import '../widgets/interactive_route_map.dart';
import '../offline/offline_maps_screen.dart';

typedef RoutesScreen = ExploreScreen;

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  int _currentTabIndex = 0; // 0: Routes & Trails, 1: Offline Maps
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showRoutePreviewModal(
      BuildContext context, RouteModel route, ActivityType activityType) {
    final isCycling = activityType == ActivityType.cycling;
    final primaryTheme =
        isCycling ? AppColors.primaryContainer : AppColors.secondaryContainer;

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
            border: Border(
                top: BorderSide(color: AppColors.outlineVariant, width: 1)),
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
                      route.name,
                      style: AppTypography.headlineSm.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: AppColors.onSurfaceVariant),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Difficulty: ${route.difficultyRating} • Trackpoints: ${route.coordinates.length} • Waypoints: ${route.waypoints.length}',
                style: AppTypography.microCaps
                    .copyWith(color: AppColors.secondaryFixed),
              ),
              const SizedBox(height: 12),

              // Interactive Route Map
              Expanded(
                child: InteractiveRouteMap(
                  route: route,
                  activityType: activityType,
                  height: double.infinity,
                ),
              ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ModalStat(
                      label: 'DISTANCE', value: '${route.totalDistanceKm} km'),
                  _ModalStat(
                      label: 'ASCENT',
                      value: '+${route.totalAscentM.toInt()}m'),
                  _ModalStat(
                      label: 'DESCENT',
                      value: '-${route.totalDescentM.toInt()}m'),
                  _ModalStat(
                      label: 'MAX ELE',
                      value: '${route.maxElevationM.toInt()}m'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final telemetry =
                        Provider.of<TelemetryService>(context, listen: false);
                    telemetry.startNavigation(route: route);
                    Navigator.pop(ctx);
                    telemetry.setSelectedTabIndex(2); // Switch to Cockpit HUD
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.surfaceContainerHighest,
                        content: Text(
                          'ACTIVATED IN COCKPIT HUD: ${route.name}',
                          style: AppTypography.bodySm
                              .copyWith(color: primaryTheme),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.navigation, size: 18),
                  label: const Text('LOAD INTO COCKPIT HUD'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryTheme,
                    foregroundColor:
                        isCycling ? AppColors.onPrimary : AppColors.onSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
    final primaryTheme =
        isCycling ? AppColors.primaryContainer : AppColors.secondaryContainer;

    final savedRoutes = telemetry.savedOfflineRoutes;
    final filteredRoutes = _searchQuery.isEmpty
        ? savedRoutes
        : savedRoutes
            .where((r) =>
                r.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Text(
              _currentTabIndex == 0 ? 'ROUTES & TRAILS' : 'OFFLINE VECTOR MAPS',
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
                  color: isCycling
                      ? AppColors.primaryContainer
                      : AppColors.secondaryFixed,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            // Segmented Top Tab Selector: [ ROUTES & TRAILS ] | [ OFFLINE MAPS ]
            Container(
              height: 40,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.outlineVariant.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _currentTabIndex = 0;
                        });
                      },
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _currentTabIndex == 0
                              ? primaryTheme
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          'ROUTES & TRAILS',
                          style: AppTypography.labelCaps.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _currentTabIndex == 0
                                ? (isCycling
                                    ? AppColors.onPrimary
                                    : AppColors.onSecondary)
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _currentTabIndex = 1;
                        });
                      },
                      borderRadius: BorderRadius.circular(9),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _currentTabIndex == 1
                              ? primaryTheme
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.download_for_offline,
                              size: 14,
                              color: _currentTabIndex == 1
                                  ? (isCycling
                                      ? AppColors.onPrimary
                                      : AppColors.onSecondary)
                                  : AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'OFFLINE MAPS',
                              style: AppTypography.labelCaps.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _currentTabIndex == 1
                                    ? (isCycling
                                        ? AppColors.onPrimary
                                        : AppColors.onSecondary)
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Tab View Body: Tab 0 (Routes) or Tab 1 (Offline Maps)
            Expanded(
              child: _currentTabIndex == 1
                  ? OfflineMapsScreen(activityType: telemetry.activityType)
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. TOP CONTROLS: Activity Toggle (Left) + Load Route Button (Right)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _ExploreActivityToggle(
                                currentActivity: telemetry.activityType,
                                onChanged: (type) {
                                  telemetry.setActivityType(type);
                                },
                              ),
                              _ExploreLoadRouteButton(
                                onTap: () {
                                  RouteLoaderModal.show(
                                      context, telemetry.activityType);
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // 2. Search & Filter Input for Saved Routes
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppColors.outlineVariant
                                      .withOpacity(0.3)),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.primary),
                              decoration: InputDecoration(
                                hintText: 'Search saved routes & GPX tracks...',
                                hintStyle: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant),
                                prefixIcon: const Icon(Icons.search,
                                    size: 18,
                                    color: AppColors.onSurfaceVariant),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear,
                                            size: 16,
                                            color: AppColors.onSurfaceVariant),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() {
                                            _searchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3. Saved Routes Section Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SAVED & IMPORTED ROUTES (${filteredRoutes.length})',
                                style: AppTypography.labelCaps.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryFixed
                                      .withOpacity(0.15),
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

                          // 4. Saved Routes List
                          if (filteredRoutes.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppColors.outlineVariant
                                        .withOpacity(0.2)),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.folder_open,
                                      size: 36,
                                      color: AppColors.onSurfaceVariant),
                                  const SizedBox(height: 10),
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No saved routes match "$_searchQuery".'
                                        : 'No saved routes yet.\nCreate a route in Planner or tap LOAD GPX to import route files.',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.bodySm.copyWith(
                                        color: AppColors.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...filteredRoutes.map((route) {
                              final isCurrentActive =
                                  telemetry.activeRoute?.id == route.id;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isCurrentActive
                                        ? primaryTheme
                                        : AppColors.outlineVariant
                                            .withOpacity(0.2),
                                    width: isCurrentActive ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          route.activityType ==
                                                  ActivityType.cycling
                                              ? Icons.directions_bike
                                              : Icons.hiking,
                                          color: route.activityType ==
                                                  ActivityType.cycling
                                              ? AppColors.primaryContainer
                                              : AppColors.secondaryContainer,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            route.name,
                                            style:
                                                AppTypography.bodyMd.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        if (isCurrentActive)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: primaryTheme,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'ACTIVE HUD',
                                              style: AppTypography.microCaps
                                                  .copyWith(
                                                color: isCycling
                                                    ? AppColors.onPrimary
                                                    : AppColors.onSecondary,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${route.totalDistanceKm} km • +${route.totalAscentM.toInt()}m ascent',
                                          style: AppTypography.microCaps
                                              .copyWith(
                                                  color: AppColors
                                                      .onSurfaceVariant),
                                        ),
                                        Text(
                                          route.difficultyRating,
                                          style: AppTypography.microCaps
                                              .copyWith(color: primaryTheme),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        // Map Preview Button
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              _showRoutePreviewModal(context,
                                                  route, route.activityType),
                                          icon: const Icon(Icons.map, size: 14),
                                          label: const Text('PREVIEW'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.primary,
                                            side: const BorderSide(
                                                color:
                                                    AppColors.outlineVariant),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8, horizontal: 10),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Activate Route Button
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            onPressed: () {
                                              telemetry
                                                  .updateActiveRoute(route);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  backgroundColor: AppColors
                                                      .surfaceContainerHighest,
                                                  content: Text(
                                                      'Loaded ${route.name} into Cockpit HUD!'),
                                                ),
                                              );
                                            },
                                            icon: const Icon(Icons.play_arrow,
                                                size: 14),
                                            label: Text(isCurrentActive
                                                ? 'LOADED IN COCKPIT'
                                                : 'ACTIVATE'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isCurrentActive
                                                  ? AppColors.surfaceBright
                                                  : primaryTheme
                                                      .withOpacity(0.2),
                                              foregroundColor: isCurrentActive
                                                  ? AppColors.primary
                                                  : primaryTheme,
                                              elevation: 0,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Delete Route Button
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline,
                                              size: 18,
                                              color:
                                                  AppColors.onSurfaceVariant),
                                          tooltip: 'Delete offline copy',
                                          onPressed: () {
                                            telemetry
                                                .removeOfflineRoute(route.id);
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
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
                color:
                    isCycling ? AppColors.primaryContainer : Colors.transparent,
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
                    color: isCycling
                        ? AppColors.onPrimary
                        : AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'CYCLING',
                    style: AppTypography.labelCaps.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isCycling
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceVariant,
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
                color: !isCycling
                    ? AppColors.secondaryContainer
                    : Colors.transparent,
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
                    color: !isCycling
                        ? AppColors.onSecondary
                        : AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'HIKING',
                    style: AppTypography.labelCaps.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: !isCycling
                          ? AppColors.onSecondary
                          : AppColors.onSurfaceVariant,
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
            const Icon(Icons.file_upload_outlined,
                size: 16, color: AppColors.secondaryFixed),
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
