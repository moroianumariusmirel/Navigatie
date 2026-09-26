import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../core/telemetry/telemetry_service.dart';
import '../../core/models/maneuver_instruction.dart';
import 'widgets/cockpit_header.dart';
import 'widgets/perspective_map_view.dart';
import 'widgets/tactical_bento_matrix.dart';

class CockpitScreen extends StatelessWidget {
  const CockpitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final telemetryService = context.watch<TelemetryService>();
    final telemetry = telemetryService.currentData;
    final activeRoute = telemetryService.activeRoute;
    final currentManeuver = telemetryService.currentManeuver ??
        activeRoute?.maneuvers.firstOrNull ??
        const ManeuverInstruction();

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
                      route: activeRoute,
                      activityType: telemetryService.activityType,
                      audioMode: telemetryService.audioMode,
                      onAudioModeChanged: telemetryService.setAudioMode,
                      navigationState: telemetryService.navigationState,
                      onPlayPause: () {
                        final willBeActive = telemetryService.navigationState != NavigationState.active;
                        telemetryService.togglePlayPauseNavigation();
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              willBeActive
                                  ? 'NAVIGATION ENGAGED • TELEMETRY ACTIVE'
                                  : 'NAVIGATION PAUSED • TELEMETRY STANDBY',
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: willBeActive
                                ? AppColors.surfaceContainerHigh
                                : AppColors.surfaceBright,
                          ),
                        );
                      },
                      onStop: () {
                        telemetryService.stopNavigation();
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('NAVIGATION STOPPED • PROGRESS RESET'),
                            duration: Duration(seconds: 2),
                            backgroundColor: AppColors.errorContainer,
                          ),
                        );
                      },
                    ),

                    // 2. Tactical Bento Matrix (Live Biomechanical & Route Metrics)
                    TacticalBentoMatrix(
                      telemetry: telemetry,
                      route: activeRoute,
                      tileOrder: telemetryService.bentoTileOrder,
                      onSwapTiles: (from, to) {
                        telemetryService.swapBentoTiles(from, to);
                      },
                      onResetOrder: () {
                        telemetryService.resetBentoTileOrder();
                      },
                      onToggleTile: (type, isEnabled) {
                        telemetryService.setTileEnabled(type, isEnabled);
                      },
                    ),

                    const SizedBox(height: 32),
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
