import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

class CockpitHeader extends StatelessWidget {
  const CockpitHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.92),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99060E20),
            offset: Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & OS Branding
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.electric_bolt,
                  color: AppColors.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRAILPULSE',
                    style: AppTypography.headlineSm.copyWith(
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'TELEMETRY OS',
                    style: AppTypography.labelCaps.copyWith(
                      fontSize: 9,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Right: Active View label & Profile
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'COCKPIT',
                  style: AppTypography.labelCaps.copyWith(
                    color: AppColors.primaryContainer,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHigh,
                  border: Border.all(
                    color: AppColors.primaryContainer.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
