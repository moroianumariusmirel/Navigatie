import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';

class MetricTile extends StatelessWidget {
  final Widget? icon;
  final String label;
  final Widget? badge;
  final String value;
  final String unit;
  final String footerLeft;
  final String footerRight;
  final bool isAlert;
  final TextStyle? valueStyle;
  final Color? customBackground;
  final Color? customValueColor;

  const MetricTile({
    super.key,
    this.icon,
    required this.label,
    this.badge,
    required this.value,
    required this.unit,
    required this.footerLeft,
    required this.footerRight,
    this.isAlert = false,
    this.valueStyle,
    this.customBackground,
    this.customValueColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = customBackground ??
        (isAlert
            ? AppColors.errorContainer.withOpacity(0.45)
            : AppColors.surfaceContainerHigh);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            offset: Offset(0, 4),
            blurRadius: 8,
          ),
        ],
        border: isAlert
            ? Border.all(color: AppColors.error.withOpacity(0.6), width: 1.5)
            : Border.all(color: AppColors.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Header: Label & Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label.toUpperCase(),
                    style: AppTypography.labelCaps.copyWith(
                      fontSize: 10,
                      color: isAlert ? AppColors.error : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (badge != null) badge!,
            ],
          ),

          const SizedBox(height: 6),

          // Main Metric & Unit
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: valueStyle ??
                    AppTypography.dataMetricXl.copyWith(
                      color: customValueColor ?? AppColors.primary,
                    ),
              ),
              const SizedBox(width: 4),
              Text(
                unit.toUpperCase(),
                style: AppTypography.labelCaps.copyWith(
                  fontSize: 10,
                  color: isAlert ? AppColors.error : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Footer info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                footerLeft,
                style: AppTypography.bodySm.copyWith(
                  fontSize: 10,
                  color: isAlert ? AppColors.error : AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                footerRight,
                style: AppTypography.labelCaps.copyWith(
                  fontSize: 10,
                  color: isAlert ? AppColors.primary : AppColors.secondaryFixed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
