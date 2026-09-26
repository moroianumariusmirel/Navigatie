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

  static Future<void> show(BuildContext context, ActivityType currentActivity) {
    return showModalBottomSheet(
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

      telemetry.updateActiveRoute(route);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceContainerHighest,
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.secondaryFixed, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'LOADED: ${route.name} (${route.totalDistanceKm} km • +${route.totalAscentM.toInt()}m)',
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

  void _loadPreset(BuildContext context, RouteModel preset) {
    final telemetry = Provider.of<TelemetryService>(context, listen: false);
    telemetry.updateActiveRoute(preset);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceContainerHighest,
        content: Text(
          'ACTIVATED: ${preset.name}',
          style: AppTypography.bodySm.copyWith(color: AppColors.secondaryFixed),
        ),
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
    return Container(
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

            // Or Instant Tactical Presets
            Text(
              'FAST TACTICAL PRESETS',
              style: AppTypography.labelCaps.copyWith(
                color: AppColors.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),

            _PresetTile(
              icon: Icons.directions_bike,
              title: 'Schauinsland KOM Ridge (Cycling)',
              stats: '42.5 km • +1,420m • S1 Flowing Singletrack',
              onTap: () => _loadPreset(context, RouteModel.sampleSchauinsland()),
            ),
            _PresetTile(
              icon: Icons.hiking,
              title: 'Feldberg Alpine Cirque Trek (Hiking)',
              stats: '18.2 km • +980m • T2 Mountain Trail',
              onTap: () => _loadPreset(context, RouteModel.sampleFeldbergHike()),
            ),

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

class _PresetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String stats;
  final VoidCallback onTap;

  const _PresetTile({
    required this.icon,
    required this.title,
    required this.stats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
      ),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.surfaceBright,
          child: Icon(icon, color: AppColors.primaryContainer, size: 18),
        ),
        title: Text(title, style: AppTypography.bodySm.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text(stats, style: AppTypography.microCaps),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}
