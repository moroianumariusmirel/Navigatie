import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

class TacticalActionBar extends StatefulWidget {
  final bool isRecording;
  final VoidCallback onToggleRecording;
  final VoidCallback onMarkWaypoint;
  final VoidCallback onTriggerSos;

  const TacticalActionBar({
    super.key,
    required this.isRecording,
    required this.onToggleRecording,
    required this.onMarkWaypoint,
    required this.onTriggerSos,
  });

  @override
  State<TacticalActionBar> createState() => _TacticalActionBarState();
}

class _TacticalActionBarState extends State<TacticalActionBar> {
  bool _isHolding = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Primary Tactile "HOLD TO PAUSE / RESUME"
          Expanded(
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isHolding = true),
              onTapUp: (_) {
                setState(() => _isHolding = false);
                widget.onToggleRecording();
              },
              onTapCancel: () => setState(() => _isHolding = false),
              child: AnimatedScale(
                scale: _isHolding ? 0.97 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: widget.isRecording
                        ? AppColors.primaryContainer
                        : AppColors.surfaceBright,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: widget.isRecording
                            ? AppColors.primaryContainer.withOpacity(0.35)
                            : const Color(0x33000000),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.isRecording ? Icons.pause : Icons.play_arrow,
                        color: widget.isRecording
                            ? AppColors.onPrimaryContainer
                            : AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.isRecording ? 'HOLD TO PAUSE' : 'TAP TO RESUME',
                        style: AppTypography.headlineSm.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: widget.isRecording
                              ? AppColors.onPrimaryContainer
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Waypoint Lap Button
          _TacticalSquareButton(
            icon: Icons.flag,
            color: AppColors.tertiaryFixedDim,
            tooltip: 'Mark Waypoint',
            onTap: widget.onMarkWaypoint,
          ),

          const SizedBox(width: 12),

          // SOS Emergency Beacon Button
          _TacticalSquareButton(
            icon: Icons.sos,
            color: AppColors.secondaryFixed,
            tooltip: 'SOS Beacon',
            onTap: widget.onTriggerSos,
          ),
        ],
      ),
    );
  }
}

class _TacticalSquareButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _TacticalSquareButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.outlineVariant.withOpacity(0.3),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }
}
