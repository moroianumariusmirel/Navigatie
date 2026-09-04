import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          'TERRAIN & EXERTION ANALYTICS',
          style: AppTypography.headlineSm.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Performance Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SESSION SUMMARY', style: AppTypography.microCaps),
                  const SizedBox(height: 10),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _AnalyticsItem(label: 'TOTAL CLIMB', value: '+1,420m'),
                      _AnalyticsItem(label: 'AVG VAM', value: '1,150 m/h'),
                      _AnalyticsItem(label: 'NORMALIZED PWR', value: '284 W'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Gradient Distribution
            Text(
              'SLOPE GRADIENT DISTRIBUTION',
              style: AppTypography.labelCaps.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  _ZoneBar(label: '0 - 3% (Flat / Rollers)', percentage: 0.35, color: AppColors.slopeFlat),
                  _ZoneBar(label: '4 - 7% (Moderate Climb)', percentage: 0.28, color: AppColors.slopeModerate),
                  _ZoneBar(label: '8 - 12% (Steep Alpine)', percentage: 0.22, color: AppColors.slopeSteep),
                  _ZoneBar(label: '15%+ (Extreme Wall)', percentage: 0.15, color: AppColors.slopeExtreme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsItem extends StatelessWidget {
  final String label;
  final String value;

  const _AnalyticsItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.microCaps),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.dataMetricMd.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ],
    );
  }
}

class _ZoneBar extends StatelessWidget {
  final String label;
  final double percentage;
  final Color color;

  const _ZoneBar({
    required this.label,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTypography.bodySm),
              Text(
                '${(percentage * 100).toInt()}%',
                style: AppTypography.microCaps.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: AppColors.surfaceContainerLowest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
