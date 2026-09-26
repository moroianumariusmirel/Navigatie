import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../core/models/maneuver_instruction.dart';
import '../../../core/navigation/audio_navigation_service.dart';
import '../../../core/telemetry/telemetry_service.dart';

class TurnGuidanceBanner extends StatelessWidget {
  final ManeuverInstruction maneuver;
  final NavigationAudioMode audioMode;
  final ValueChanged<NavigationAudioMode>? onAudioModeChanged;
  final bool isOffRoute;
  final NavigationState navigationState;
  final VoidCallback? onPlayPause;
  final VoidCallback? onStop;

  const TurnGuidanceBanner({
    super.key,
    required this.maneuver,
    this.audioMode = NavigationAudioMode.voiceAndChimes,
    this.onAudioModeChanged,
    this.isOffRoute = false,
    this.navigationState = NavigationState.stopped,
    this.onPlayPause,
    this.onStop,
  });

  void _cycleAudioMode() {
    if (onAudioModeChanged == null) return;
    final nextMode = switch (audioMode) {
      NavigationAudioMode.voiceAndChimes => NavigationAudioMode.chimesOnly,
      NavigationAudioMode.chimesOnly => NavigationAudioMode.muted,
      NavigationAudioMode.muted => NavigationAudioMode.voiceAndChimes,
    };
    onAudioModeChanged!(nextMode);
  }

  IconData get _audioIcon => switch (audioMode) {
    NavigationAudioMode.voiceAndChimes => Icons.volume_up_rounded,
    NavigationAudioMode.chimesOnly => Icons.notifications_active_rounded,
    NavigationAudioMode.muted => Icons.volume_off_rounded,
  };

  String get _audioTooltip => switch (audioMode) {
    NavigationAudioMode.voiceAndChimes => 'Voice & Chimes',
    NavigationAudioMode.chimesOnly => 'Chimes Only',
    NavigationAudioMode.muted => 'Muted',
  };

  Color get _audioColor => switch (audioMode) {
    NavigationAudioMode.voiceAndChimes => AppColors.primary,
    NavigationAudioMode.chimesOnly => AppColors.secondaryFixed,
    NavigationAudioMode.muted => AppColors.outline,
  };

  @override
  Widget build(BuildContext context) {
    final isImminent = maneuver.distanceToManeuverMeters <= 25 && maneuver.distanceToManeuverMeters > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isOffRoute
            ? AppColors.errorContainer.withOpacity(0.95)
            : isImminent
                ? AppColors.surfaceContainerHighest.withOpacity(0.98)
                : AppColors.surfaceContainerHigh.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isOffRoute
                ? AppColors.error.withOpacity(0.3)
                : const Color(0x66060E20),
            offset: const Offset(0, 6),
            blurRadius: 16,
          ),
        ],
        border: Border.all(
          color: isOffRoute
              ? AppColors.error
              : isImminent
                  ? AppColors.primary.withOpacity(0.8)
                  : AppColors.outlineVariant.withOpacity(0.4),
          width: isImminent || isOffRoute ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          // Maneuver Icon Tile
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isOffRoute
                  ? AppColors.error
                  : isImminent
                      ? AppColors.primary
                      : AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isOffRoute ? AppColors.error : AppColors.primaryContainer).withOpacity(0.35),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              isOffRoute ? Icons.wrong_location_rounded : maneuver.icon,
              color: (isOffRoute || isImminent) ? Colors.white : AppColors.onPrimaryContainer,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),

          // Maneuver Instruction Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      isOffRoute ? 'OFF ROUTE' : '${maneuver.distanceToManeuverMeters}m',
                      style: AppTypography.headlineSm.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isOffRoute ? AppColors.error : AppColors.primary,
                        fontSize: isOffRoute ? 16 : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isOffRoute
                            ? 'RETURN TO TRACK'
                            : maneuver.instructionTitle.toUpperCase(),
                        style: AppTypography.labelCaps.copyWith(
                          color: isOffRoute ? AppColors.onErrorContainer : AppColors.secondaryFixed,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isOffRoute
                      ? 'GPS alert chime active'
                      : '${maneuver.trailName} • ${maneuver.surfaceType}',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Audio Mode 1-Tap Toggle Button
          Material(
            color: Colors.transparent,
            child: Tooltip(
              message: 'Audio: $_audioTooltip (Tap to change)',
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _cycleAudioMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _audioColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _audioIcon,
                        color: _audioColor,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Play/Pause & Hold-to-Stop Navigation Control
          _NavControlPill(
            navigationState: navigationState,
            onPlayPause: onPlayPause,
            onStop: onStop,
          ),
        ],
      ),
    );
  }
}

class _NavControlPill extends StatelessWidget {
  final NavigationState navigationState;
  final VoidCallback? onPlayPause;
  final VoidCallback? onStop;

  const _NavControlPill({
    required this.navigationState,
    this.onPlayPause,
    this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = navigationState == NavigationState.active;
    final isPaused = navigationState == NavigationState.paused;
    final isStopped = navigationState == NavigationState.stopped;

    final IconData icon = isActive ? Icons.pause_rounded : Icons.play_arrow_rounded;

    final Color iconColor = isActive
        ? AppColors.onPrimaryContainer
        : isPaused
            ? AppColors.secondaryFixed
            : AppColors.primary;

    final Color bgColor = isActive
        ? AppColors.primaryContainer
        : isPaused
            ? AppColors.surfaceBright.withOpacity(0.85)
            : AppColors.surfaceContainerLowest.withOpacity(0.6);

    final Color borderColor = isActive
        ? AppColors.primary
        : isPaused
            ? AppColors.secondaryFixed.withOpacity(0.6)
            : AppColors.primary.withOpacity(0.4);

    final String tooltip = isActive
        ? 'Tap to Pause • Hold to Stop'
        : isPaused
            ? 'Tap to Resume • Hold to Stop'
            : 'Tap to Start Navigation';

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          key: const Key('nav_play_pause_button'),
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            HapticFeedback.lightImpact();
            onPlayPause?.call();
          },
          onLongPress: isStopped
              ? null
              : () {
                  HapticFeedback.heavyImpact();
                  onStop?.call();
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: isStopped ? 10 : 8,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: borderColor,
                width: isActive ? 1.5 : 1.0,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : (isPaused
                      ? [
                          BoxShadow(
                            color: AppColors.secondaryFixed.withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: iconColor,
                  size: 18,
                ),
                if (!isStopped) ...[
                  const SizedBox(width: 5),
                  Text(
                    'HOLD TO STOP',
                    style: AppTypography.microCaps.copyWith(
                      color: iconColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

