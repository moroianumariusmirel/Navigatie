import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../core/models/maneuver_instruction.dart';

class TurnGuidanceBanner extends StatelessWidget {
  final ManeuverInstruction maneuver;

  const TurnGuidanceBanner({
    super.key,
    required this.maneuver,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66060E20),
            offset: Offset(0, 6),
            blurRadius: 16,
          ),
        ],
        border: Border.all(
          color: AppColors.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          // Maneuver Icon Tile
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryContainer.withOpacity(0.35),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Icon(
              maneuver.icon,
              color: AppColors.onPrimaryContainer,
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
                      '${maneuver.distanceToManeuverMeters}m',
                      style: AppTypography.headlineSm.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
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
                    Text(
                      maneuver.instructionTitle.toUpperCase(),
                      style: AppTypography.labelCaps.copyWith(
                        color: AppColors.secondaryFixed,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${maneuver.trailName} • ${maneuver.surfaceType}',
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

          // Route Apex callout
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ROUTE APEX',
                style: AppTypography.microCaps.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
              Text(
                '${maneuver.apexElevationM.toInt()}m',
                style: AppTypography.dataMetricMd.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
