import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.95),
        boxShadow: const [
          BoxShadow(
            color: Color(0xCC060E20),
            offset: Offset(0, -4),
            blurRadius: 20,
          ),
        ],
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            icon: Icons.explore,
            label: 'Explore',
            isSelected: currentIndex == 0,
            onTap: () => onTabSelected(0),
          ),
          _NavItem(
            icon: Icons.alt_route,
            label: 'Planner',
            isSelected: currentIndex == 1,
            onTap: () => onTabSelected(1),
          ),
          _NavItem(
            icon: Icons.speed,
            label: 'Cockpit',
            isSelected: currentIndex == 2,
            onTap: () => onTabSelected(2),
          ),
          _NavItem(
            icon: Icons.query_stats,
            label: 'Stats',
            isSelected: currentIndex == 3,
            onTap: () => onTabSelected(3),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.surfaceContainerHigh.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryContainer : AppColors.onSurfaceVariant,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: AppTypography.labelCaps.copyWith(
                fontSize: 10,
                color: isSelected ? AppColors.primaryContainer : AppColors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
