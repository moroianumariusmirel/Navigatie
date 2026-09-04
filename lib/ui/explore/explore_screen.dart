import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../core/offline/offline_tile_manager.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final regions = OfflineTileManager.sampleRegions();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'EXPLORE & OFFLINE REGIONS',
          style: AppTypography.headlineSm.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'DOWNLOADED OFFLINE MAPS & ROUTING',
            style: AppTypography.labelCaps.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...regions.map((region) {
            final isReady = region.state == RegionDownloadState.ready;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isReady
                      ? AppColors.primaryContainer.withOpacity(0.5)
                      : AppColors.outlineVariant.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          region.name,
                          style: AppTypography.headlineSm.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isReady
                              ? AppColors.primaryContainer
                              : AppColors.surfaceBright,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isReady ? 'DOWNLOADED' : '${region.sizeMb} MB',
                          style: AppTypography.microCaps.copyWith(
                            color: isReady
                                ? AppColors.onPrimaryContainer
                                : AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    region.description,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        isReady ? Icons.check_circle : Icons.cloud_download,
                        color: isReady ? AppColors.primaryContainer : AppColors.secondaryFixed,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isReady
                            ? 'Ready for offline navigation (PMTiles + Valhalla)'
                            : 'Tap to download for 100% offline usage',
                        style: AppTypography.microCaps.copyWith(
                          color: isReady ? AppColors.primaryContainer : AppColors.secondaryFixed,
                        ),
                      ),
                    ],
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
