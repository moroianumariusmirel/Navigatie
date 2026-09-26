import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../core/telemetry/telemetry_service.dart';
import '../../../core/permissions/permission_service.dart';

class CockpitHeader extends StatelessWidget {
  const CockpitHeader({super.key});

  void _showPermissionDiagnostics(BuildContext context, TelemetryService telemetry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final status = telemetry.permissionStatus;
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.security, color: AppColors.primary, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    'DEVICE SENSORS & STORAGE',
                    style: AppTypography.headlineSm.copyWith(
                      color: AppColors.primary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDiagTile(
                title: 'GPS SENSOR (LOCATION)',
                subtitle: status.isLocationGranted
                    ? 'Active • High Accuracy Positioning'
                    : 'Permission Not Granted (Simulated GPS Active)',
                isOk: status.isLocationGranted,
                icon: Icons.gps_fixed,
              ),
              const SizedBox(height: 12),
              _buildDiagTile(
                title: 'DEVICE STORAGE (GPX FILES)',
                subtitle: status.isStorageGranted
                    ? 'Active • Trails Saved to Local Documents'
                    : 'Storage Permission Pending',
                isOk: status.isStorageGranted,
                icon: Icons.folder,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final newStatus = await PermissionService.requestInitialAppPermissions();
                  telemetry.updatePermissionStatus(newStatus);
                  if (newStatus.isLocationPermanentlyDenied || newStatus.isStoragePermanentlyDenied) {
                    await PermissionService.openSettings();
                  }
                },
                child: Text(
                  status.areAllGranted
                      ? 'RE-VERIFY SENSORS'
                      : 'GRANT SENSOR & STORAGE ACCESS',
                  style: AppTypography.labelCaps.copyWith(
                    color: AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiagTile({
    required String title,
    required String subtitle,
    required bool isOk,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isOk ? AppColors.primaryContainer.withOpacity(0.5) : AppColors.error.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isOk ? AppColors.primaryContainer : AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelCaps.copyWith(
                    color: isOk ? AppColors.primary : AppColors.error,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOk ? AppColors.primaryContainer : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final telemetryService = context.watch<TelemetryService>();
    final permStatus = telemetryService.permissionStatus;
    final isGpsOk = permStatus.isLocationGranted;

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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryContainer.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    fit: BoxFit.contain,
                  ),
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

          // Right: GPS Status Badge & Diagnostics Trigger
          Row(
            children: [
              // GPS Status Pill
              GestureDetector(
                onTap: () => _showPermissionDiagnostics(context, telemetryService),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isGpsOk
                        ? AppColors.primaryContainer.withOpacity(0.15)
                        : AppColors.error.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isGpsOk
                          ? AppColors.primaryContainer.withOpacity(0.4)
                          : AppColors.error.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isGpsOk ? AppColors.primaryContainer : AppColors.error,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isGpsOk ? 'GPS LOCK' : 'GPS OFF',
                        style: AppTypography.labelCaps.copyWith(
                          color: isGpsOk ? AppColors.primaryContainer : AppColors.error,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Diagnostics / Profile Button
              GestureDetector(
                onTap: () => _showPermissionDiagnostics(context, telemetryService),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceContainerHigh,
                    border: Border.all(
                      color: AppColors.primaryContainer.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.tune,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
