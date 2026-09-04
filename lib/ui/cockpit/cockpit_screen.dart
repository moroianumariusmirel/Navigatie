import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../core/telemetry/telemetry_service.dart';
import '../../core/models/maneuver_instruction.dart';
import 'widgets/cockpit_header.dart';
import 'widgets/perspective_map_view.dart';
import 'widgets/tactical_bento_matrix.dart';
import 'widgets/elevation_slicer_widget.dart';
import 'widgets/tactical_action_bar.dart';

class CockpitScreen extends StatelessWidget {
  const CockpitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final telemetryService = context.watch<TelemetryService>();
    final telemetry = telemetryService.currentData;
    final activeRoute = telemetryService.activeRoute;
    final currentManeuver = activeRoute?.maneuvers.first ?? const ManeuverInstruction();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            // Top Header
            const CockpitHeader(),

            // Scrollable Cockpit Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top 3D Perspective Map & Spatial HUD
                    PerspectiveMapView(
                      telemetry: telemetry,
                      maneuver: currentManeuver,
                    ),

                    // 2. Tactical Bento Matrix (6 Live Biomechanical Metrics)
                    TacticalBentoMatrix(
                      telemetry: telemetry,
                    ),

                    // 3. Elevation Contour Slicer & Slope Severity
                    ElevationSlicerWidget(
                      telemetry: telemetry,
                      route: activeRoute,
                    ),

                    // 4. Interactive Tactile Controls Drawer / Action Strip
                    TacticalActionBar(
                      isRecording: telemetryService.isRecording,
                      onToggleRecording: () => telemetryService.toggleRecording(),
                      onMarkWaypoint: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Waypoint Lap Marked • GPS Locked'),
                            duration: Duration(seconds: 2),
                            backgroundColor: AppColors.surfaceContainerHigh,
                          ),
                        );
                      },
                      onTriggerSos: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('SOS Emergency Beacon Broadcast Initiated'),
                            duration: Duration(seconds: 3),
                            backgroundColor: AppColors.errorContainer,
                          ),
                        );
                      },
                    ),

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
