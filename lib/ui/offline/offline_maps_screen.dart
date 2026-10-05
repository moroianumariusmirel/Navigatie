import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../core/models/activity_type.dart';
import '../../core/offline/offline_download_service.dart';
import '../../core/offline/offline_tile_manager.dart';
import '../../core/offline/device_storage_service.dart';

class OfflineMapsScreen extends StatefulWidget {
  final ActivityType activityType;

  const OfflineMapsScreen({
    super.key,
    required this.activityType,
  });

  @override
  State<OfflineMapsScreen> createState() => _OfflineMapsScreenState();
}

class _OfflineMapsScreenState extends State<OfflineMapsScreen> {
  final OfflineDownloadService _downloadService = OfflineDownloadService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedActivityFilter = 'ALL'; // 'ALL', 'CYCLING', 'HIKING'
  final Set<String> _expandedCountries = {};

  @override
  void initState() {
    super.initState();
    _downloadService.initialize();
    _downloadService.addListener(_onServiceUpdate);
  }

  @override
  void dispose() {
    _downloadService.removeListener(_onServiceUpdate);
    _searchController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleCountryExpanded(String countryId) {
    setState(() {
      if (_expandedCountries.contains(countryId)) {
        _expandedCountries.remove(countryId);
      } else {
        _expandedCountries.add(countryId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isCycling = widget.activityType == ActivityType.cycling;
    final primaryTheme = isCycling ? AppColors.primaryContainer : AppColors.secondaryContainer;

    final filteredCountries = _getFilteredCountries();
    final downloadedCount = _downloadService.downloadedRegions.length;
    final totalStorageMb = _downloadService.totalStorageUsedMb;

    return Column(
      children: [
        // 1. Storage Header Meter & Import Button
        _buildStorageCard(primaryTheme, downloadedCount, totalStorageMb),

        const SizedBox(height: 12),

        // 2. Search & Tag Filters
        _buildSearchAndFilters(primaryTheme),

        const SizedBox(height: 12),

        // 3. Countries List with Accordion Regional Sub-Packs
        Expanded(
          child: filteredCountries.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filteredCountries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final country = filteredCountries[index];
                    final isExpanded = _expandedCountries.contains(country.id);
                    return _buildCountryCard(country, isExpanded, primaryTheme);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStorageCard(Color themeColor, int downloadedCount, double totalStorageMb) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: themeColor.withOpacity(0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.offline_pin_rounded, color: themeColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'OFFLINE VECTOR MAPS',
                    style: AppTypography.labelCaps.copyWith(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              // Import local .pmtiles button
              InkWell(
                onTap: () async {
                  final result = await _downloadService.importLocalPmtilesFile();
                  if (result != null && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        content: Text(
                          'Imported offline map: ${result.name} (${result.sizeMb} MB)',
                          style: const TextStyle(color: AppColors.primaryContainer),
                        ),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.file_open_outlined, color: themeColor, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'IMPORT .PMTILES',
                        style: AppTypography.microCaps.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DEVICE STORAGE USED',
                      style: AppTypography.microCaps.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      totalStorageMb >= 1024
                          ? '${(totalStorageMb / 1024).toStringAsFixed(2)} GB'
                          : '${totalStorageMb.toStringAsFixed(1)} MB',
                      style: AppTypography.dataMetricMd.copyWith(
                        color: themeColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 32,
                color: AppColors.outlineVariant.withOpacity(0.3),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'READY PACKS',
                      style: AppTypography.microCaps.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$downloadedCount REGIONS',
                      style: AppTypography.dataMetricMd.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(Color themeColor) {
    return Column(
      children: [
        // Search bar
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
                _searchQuery = val.trim();
              });
            },
            style: const TextStyle(fontSize: 13, color: AppColors.primary),
            decoration: InputDecoration(
              hintText: 'Search European country, region, Alps, Carpathians...',
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
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Activity tag filter chips
        Row(
          children: [
            _buildFilterChip('ALL', 'ALL MAPS', themeColor),
            const SizedBox(width: 8),
            _buildFilterChip('CYCLING', '🚴 CYCLING & GRAVEL', themeColor),
            const SizedBox(width: 8),
            _buildFilterChip('HIKING', '🥾 HIKING & TRAILS', themeColor),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label, Color themeColor) {
    final isSelected = _selectedActivityFilter == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedActivityFilter = value;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? themeColor.withOpacity(0.18) : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? themeColor : AppColors.outlineVariant.withOpacity(0.3),
              width: isSelected ? 1.2 : 0.8,
            ),
          ),
          child: Text(
            label,
            style: AppTypography.microCaps.copyWith(
              color: isSelected ? themeColor : AppColors.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 9,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountryCard(OfflineCountry country, bool isExpanded, Color themeColor) {
    final master = country.masterRegion;
    final subRegions = country.subRegions;
    final readyCount = country.downloadedRegionsCount;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: readyCount > 0
              ? themeColor.withOpacity(0.4)
              : AppColors.outlineVariant.withOpacity(0.2),
          width: readyCount > 0 ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        children: [
          // Country Header
          InkWell(
            onTap: () => _toggleCountryExpanded(country.id),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Text(
                    country.flag,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          country.name.toUpperCase(),
                          style: AppTypography.headlineSm.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${subRegions.length} sub-regions • ~${country.totalSizeMb.toStringAsFixed(0)} MB complete',
                          style: AppTypography.microCaps.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (readyCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: themeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: themeColor.withOpacity(0.4)),
                      ),
                      child: Text(
                        '$readyCount READY',
                        style: AppTypography.microCaps.copyWith(
                          color: themeColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Regional Sub-Packs & Master pack
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.outlineVariant),
            // Master Pack if present
            if (master != null) ...[
              _buildRegionTile(master, themeColor, isMaster: true),
              const Divider(height: 1, color: AppColors.outlineVariant),
            ],
            // Sub-regions
            ...subRegions.map((region) => _buildRegionTile(region, themeColor)),
          ],
        ],
      ),
    );
  }

  Widget _buildRegionTile(OfflineMapRegion region, Color themeColor, {bool isMaster = false}) {
    final isDownloading = region.state == RegionDownloadState.downloading;
    final isReady = region.state == RegionDownloadState.ready;
    final isFailed = region.state == RegionDownloadState.failed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isMaster)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'FULL NATION',
                              style: AppTypography.microCaps.copyWith(
                                color: AppColors.secondaryFixed,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        Flexible(
                          child: Text(
                            region.name,
                            style: AppTypography.headlineSm.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isReady
                                  ? themeColor
                                  : (isFailed ? AppColors.error : AppColors.primary),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      region.description,
                      style: AppTypography.microCaps.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 9,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Size badge
              Text(
                '${region.sizeMb.toStringAsFixed(0)} MB',
                style: AppTypography.dataMetricMd.copyWith(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),

              // Action buttons (Download / Cancel / Retry / Delete)
              if (isReady) ...[
                IconButton(
                  tooltip: 'Delete offline map file',
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.surfaceContainerHigh,
                        title: const Text('Delete Map Pack?', style: TextStyle(color: AppColors.primary)),
                        content: Text(
                          'Are you sure you want to delete ${region.name} (${region.sizeMb.toStringAsFixed(0)} MB) from local device storage?',
                          style: const TextStyle(color: AppColors.onSurface),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('CANCEL'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('DELETE', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await _downloadService.deleteRegion(region.id);
                    }
                  },
                ),
              ] else if (isDownloading) ...[
                IconButton(
                  tooltip: 'Cancel download',
                  icon: const Icon(Icons.cancel_outlined, size: 18, color: AppColors.onSurfaceVariant),
                  onPressed: () {
                    _downloadService.cancelDownload(region.id);
                  },
                ),
              ] else if (isFailed) ...[
                IconButton(
                  tooltip: 'Retry download',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: AppColors.error,
                  ),
                  onPressed: () {
                    _downloadService.startDownload(region);
                  },
                ),
              ] else ...[
                IconButton(
                  tooltip: 'Download offline pack',
                  icon: Icon(
                    Icons.download_rounded,
                    size: 19,
                    color: themeColor,
                  ),
                  onPressed: () {
                    _downloadService.startDownload(region);
                  },
                ),
              ],
            ],
          ),

          // Error display if failed
          if (isFailed && region.errorMessage != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.error_outline, size: 12, color: AppColors.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    region.errorMessage!,
                    style: AppTypography.microCaps.copyWith(
                      color: AppColors.error,
                      fontSize: 8.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          // Download progress bar
          if (isDownloading) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: region.downloadProgress,
                backgroundColor: AppColors.surfaceContainerLowest,
                valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(region.downloadProgress * 100).toStringAsFixed(0)}% • ${DeviceStorageService.formatBytes(region.downloadedBytes)} / ${region.sizeMb.toStringAsFixed(0)} MB',
                  style: AppTypography.microCaps.copyWith(
                    color: themeColor,
                    fontSize: 9,
                  ),
                ),
                Text(
                  'STREAMING PMTILES',
                  style: AppTypography.microCaps.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.travel_explore, size: 48, color: AppColors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'No matching countries or regions found',
            style: AppTypography.headlineSm.copyWith(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try searching for "Romania", "Alps", "Bavaria", or "Transylvania"',
            style: AppTypography.microCaps.copyWith(
              color: AppColors.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  List<OfflineCountry> _getFilteredCountries() {
    final query = _searchQuery.toLowerCase();
    return _downloadService.countries.where((country) {
      // 1. Activity filter check
      final matchesActivity = _selectedActivityFilter == 'ALL' ||
          country.regions.any((r) {
            if (_selectedActivityFilter == 'CYCLING') return r.hasCyclingProfiles;
            if (_selectedActivityFilter == 'HIKING') return r.hasHikingContours;
            return true;
          });

      if (!matchesActivity) return false;

      // 2. Query check
      if (query.isEmpty) return true;
      if (country.name.toLowerCase().contains(query)) return true;
      return country.regions.any((r) =>
          r.name.toLowerCase().contains(query) ||
          r.description.toLowerCase().contains(query));
    }).toList();
  }
}
