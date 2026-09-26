import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../../core/routing/gpx_parser.dart';
import '../../../core/models/activity_type.dart';
import '../../../core/models/route_model.dart';

class RouteLoaderModal extends StatefulWidget {
  final ActivityType currentActivity;

  const RouteLoaderModal({super.key, required this.currentActivity});

  static Future<RouteModel?> show(BuildContext context, ActivityType currentActivity) {
    return showModalBottomSheet<RouteModel>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => RouteLoaderModal(currentActivity: currentActivity),
    );
  }

  @override
  State<RouteLoaderModal> createState() => _RouteLoaderModalState();
}

class _RouteLoaderModalState extends State<RouteLoaderModal> {
  bool _isLoading = false;
  String? _statusMessage;
  final TextEditingController _pasteController = TextEditingController();
  bool _showPasteArea = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<TelemetryService>(context, listen: false).loadSavedRoutesFromDisk();
      }
    });
  }

  Future<void> _pickFile() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Opening system file selector...';
    });

    try {
      // On mobile devices (Android/iOS), using FileType.custom causes Android's
      // Storage Access Framework (SAF) to filter strictly by MIME types.
      // Since Android has no registered MIME type for GPX/KML/GeoJSON, it grays out
      // and disables .gpx files in the file selector.
      // Using FileType.any on mobile allows selecting any route file, and we
      // validate the extension directly in Dart.
      final result = await FilePicker.platform.pickFiles(
        type: kIsWeb ? FileType.custom : FileType.any,
        allowedExtensions: kIsWeb ? ['gpx', 'kml', 'xml', 'json', 'geojson'] : null,
        withData: true,
      );

      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final name = file.name;
        final ext = (file.extension ?? (name.contains('.') ? name.split('.').last : '')).toLowerCase();
        const validExtensions = ['gpx', 'kml', 'xml', 'json', 'geojson'];

        if (ext.isNotEmpty && !validExtensions.contains(ext)) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'Unsupported file format (.$ext). Please select a .gpx, .kml, or .geojson route.';
          });
          return;
        }

        List<int>? bytes = file.bytes;
        bytes ??= await file.xFile.readAsBytes();

        if (bytes.isEmpty) {
          setState(() {
            _isLoading = false;
            _statusMessage = 'Selected file is empty.';
          });
          return;
        }

        String content;
        try {
          content = utf8.decode(bytes);
        } catch (_) {
          content = latin1.decode(bytes);
        }

        if (content.startsWith('\uFEFF')) {
          content = content.substring(1);
        }

        if (!mounted) return;
        _processContent(context, content, name);
        return;
      }
      setState(() {
        _isLoading = false;
        _statusMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'File error: $e';
      });
    }
  }

  void _processContent(BuildContext context, String content, String fileName) {
    try {
      final telemetry = Provider.of<TelemetryService>(context, listen: false);
      final lowerName = fileName.toLowerCase();
      RouteModel route;
      if (content.trim().startsWith('{') || lowerName.endsWith('.json') || lowerName.endsWith('.geojson')) {
        route = GpxParser.parseGeoJson(content, defaultActivity: widget.currentActivity, fallbackName: fileName);
      } else {
        route = GpxParser.parseGpx(content, defaultActivity: widget.currentActivity, fallbackName: fileName);
      }

      // Automatically save imported route to offline library & disk
      telemetry.saveRouteOffline(route);
      telemetry.updateActiveRoute(route);
      Navigator.pop(context, route);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceContainerHighest,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.secondaryFixed, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'LOADED & SAVED: ${route.name} (${route.totalDistanceKm.toStringAsFixed(1)} km • +${route.totalAscentM.toInt()}m)',
                  style: AppTypography.bodySm.copyWith(color: AppColors.primary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Parse error: Could not parse route file ($e)';
      });
    }
  }

  void _selectRoute(BuildContext context, RouteModel route) {
    final telemetry = Provider.of<TelemetryService>(context, listen: false);
    telemetry.updateActiveRoute(route);
    Navigator.pop(context, route);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceContainerHighest,
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.primaryContainer, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'LOADED: ${route.name} (${route.totalDistanceKm.toStringAsFixed(1)} km • +${route.totalAscentM.toInt()}m)',
                style: AppTypography.bodySm.copyWith(color: AppColors.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final telemetry = Provider.of<TelemetryService>(context);
    final savedRoutes = telemetry.savedOfflineRoutes;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.outlineVariant, width: 1)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
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
            const SizedBox(height: 16),

            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'IMPORT ROUTE / TRACK',
                      style: AppTypography.headlineSm.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SUPPORTED: GPX 1.1 • GEOJSON • KML • FIT',
                      style: AppTypography.microCaps.copyWith(
                        color: AppColors.secondaryFixed,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.onSurfaceVariant),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_statusMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.errorContainer),
                ),
                child: Text(
                  _statusMessage!,
                  style: AppTypography.bodySm.copyWith(color: AppColors.error),
                ),
              ),

            // Primary Action: Pick File
            InkWell(
              onTap: _isLoading ? null : () => _pickFile(),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryContainer.withOpacity(0.18),
                      AppColors.secondaryContainer.withOpacity(0.12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primaryContainer.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.file_upload_outlined, color: AppColors.primaryContainer, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      _isLoading ? 'READING FILE...' : 'SELECT GPX / ROUTE FILE',
                      style: AppTypography.labelCaps.copyWith(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ==========================================
            // Saved Routes & Files List (User's already saved files)
            // ==========================================
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.folder_special_outlined, size: 18, color: AppColors.primaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      'MY SAVED FILES & ROUTES (${savedRoutes.length})',
                      style: AppTypography.labelCaps.copyWith(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryFixed.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'OFFLINE READY',
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
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.folder_open, size: 30, color: AppColors.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(
                      'No saved routes found on device yet',
                      style: AppTypography.bodySm.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Import a GPX file above or create and save routes in Planner.',
                      textAlign: TextAlign.center,
                      style: AppTypography.microCaps.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...savedRoutes.map((route) {
                final isCurrentActive = telemetry.activeRoute?.id == route.id;
                final isCycling = route.activityType == ActivityType.cycling;
                final themeColor = isCycling ? AppColors.primaryContainer : AppColors.secondaryContainer;

                return _SavedRouteTile(
                  route: route,
                  isActive: isCurrentActive,
                  themeColor: themeColor,
                  onTap: () => _selectRoute(context, route),
                  onDelete: () {
                    telemetry.removeOfflineRoute(route.id);
                  },
                );
              }),

            const SizedBox(height: 12),

            // Direct XML/Text Paste Toggle
            InkWell(
              onTap: () {
                setState(() {
                  _showPasteArea = !_showPasteArea;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      _showPasteArea ? Icons.arrow_drop_down : Icons.arrow_right,
                      color: AppColors.secondaryFixed,
                    ),
                    Text(
                      'PASTE RAW GPX / GEOJSON TEXT',
                      style: AppTypography.microCaps.copyWith(
                        color: AppColors.secondaryFixed,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_showPasteArea) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _pasteController,
                maxLines: 4,
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 11,
                  color: AppColors.primary,
                ),
                decoration: InputDecoration(
                  hintText: 'Paste <?xml ... <gpx>... or GeoJSON here',
                  hintStyle: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  filled: true,
                  fillColor: AppColors.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.outlineVariant),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  final text = _pasteController.text.trim();
                  if (text.isNotEmpty) {
                    _processContent(context, text, 'Pasted Route');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryContainer,
                  foregroundColor: AppColors.onSecondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('PARSE & LOAD PASTED TRACK'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SavedRouteTile extends StatelessWidget {
  final RouteModel route;
  final bool isActive;
  final Color themeColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SavedRouteTile({
    required this.route,
    required this.isActive,
    required this.themeColor,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isCycling = route.activityType == ActivityType.cycling;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? themeColor : AppColors.outlineVariant.withOpacity(0.25),
          width: isActive ? 1.5 : 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: themeColor.withOpacity(0.18),
                  child: Icon(
                    isCycling ? Icons.directions_bike : Icons.hiking,
                    color: themeColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              route.name,
                              style: AppTypography.bodySm.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isActive)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: themeColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: AppTypography.microCaps.copyWith(
                                  color: themeColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Text(
                            '${route.totalDistanceKm.toStringAsFixed(1)} km',
                            style: AppTypography.microCaps.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('•', style: AppTypography.microCaps.copyWith(color: AppColors.outline)),
                          const SizedBox(width: 6),
                          Text(
                            '+${route.totalAscentM.toInt()}m',
                            style: AppTypography.microCaps.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          if (route.waypoints.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text('•', style: AppTypography.microCaps.copyWith(color: AppColors.outline)),
                            const SizedBox(width: 6),
                            Text(
                              '${route.waypoints.length} stops',
                              style: AppTypography.microCaps.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(width: 6),
                          Text('•', style: AppTypography.microCaps.copyWith(color: AppColors.outline)),
                          Text(
                            isCycling ? 'CYCLING' : 'HIKING',
                            style: AppTypography.microCaps.copyWith(
                              color: themeColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.onSurfaceVariant),
                  tooltip: 'Delete file',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
                const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
