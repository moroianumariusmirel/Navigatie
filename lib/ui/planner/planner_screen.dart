import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../core/models/route_model.dart';

class PlannerScreen extends StatelessWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final route = RouteModel.sampleSchauinsland();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'ELEVATION & ROUTE PLANNER',
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
            // Route Title Card
            Container(
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
                          color: AppColors.primaryContainer.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'GRAVEL / MTB PROFILE',
                          style: AppTypography.microCaps.copyWith(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        'OFFLINE READY',
                        style: AppTypography.microCaps.copyWith(
                          color: AppColors.secondaryFixed,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    route.name,
                    style: AppTypography.headlineSm.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 14),
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
            ),

            const SizedBox(height: 20),

            // Surface Breakdown Card
            Text(
              'TRAIL SURFACE BREAKDOWN',
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 14,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 65,
                            child: Container(color: AppColors.primaryContainer),
                          ),
                          Expanded(
                            flex: 25,
                            child: Container(color: AppColors.secondaryContainer),
                          ),
                          Expanded(
                            flex: 10,
                            child: Container(color: AppColors.surfaceBright),
                          ),
                        ],
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
                              color: AppColors.primaryContainer,
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

            const SizedBox(height: 20),

            // Waypoints List
            Text(
              'PLANNED WAYPOINTS',
              style: AppTypography.labelCaps.copyWith(
                color: AppColors.onSurfaceVariant,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            const _WaypointTile(
              index: 1,
              title: 'Start: Kirchzarten Valley',
              elevation: '1,250m',
              distance: '0.0 km',
            ),
            const _WaypointTile(
              index: 2,
              title: 'Schauinsland Ridge (Apex)',
              elevation: '2,191m',
              distance: '35.0 km',
              isApex: true,
            ),
            const _WaypointTile(
              index: 3,
              title: 'Finish: Hinterzarten Lodge',
              elevation: '1,400m',
              distance: '42.5 km',
            ),
          ],
        ),
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
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _WaypointTile extends StatelessWidget {
  final int index;
  final String title;
  final String elevation;
  final String distance;
  final bool isApex;

  const _WaypointTile({
    required this.index,
    required this.title,
    required this.elevation,
    required this.distance,
    this.isApex = false,
  });

  @override
  Widget build(BuildContext context) {
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
              '$index',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isApex ? AppColors.onError : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title, style: AppTypography.bodyMd),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                elevation,
                style: AppTypography.dataMetricMd.copyWith(
                  fontSize: 13,
                  color: isApex ? AppColors.error : AppColors.primary,
                ),
              ),
              Text(distance, style: AppTypography.microCaps),
            ],
          ),
        ],
      ),
    );
  }
}
