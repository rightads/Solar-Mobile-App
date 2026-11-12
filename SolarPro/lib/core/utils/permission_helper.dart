import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

enum PermissionType {
  camera,
  gallery,
  location,
  notifications;

  String get title {
    switch (this) {
      case PermissionType.camera:
        return 'Camera Permission';
      case PermissionType.gallery:
        return 'Storage & Gallery Permission';
      case PermissionType.location:
        return 'Location Permission';
      case PermissionType.notifications:
        return 'Notifications Permission';
    }
  }

  String get rationale {
    switch (this) {
      case PermissionType.camera:
        return 'SolarPro needs camera access to capture installation photo proofs, inspect solar panels, and scan equipment serial barcodes on site.';
      case PermissionType.gallery:
        return 'SolarPro needs access to photos and documents to upload customer KYC, electricity bills, site layout plans, and payment receipts.';
      case PermissionType.location:
        return 'SolarPro uses location coordinates for precise solar irradiation calculations, customer site geotagging, and technician check-in.';
      case PermissionType.notifications:
        return 'SolarPro sends timely alerts when new leads are assigned, site work orders are scheduled, or urgent service tickets are raised.';
    }
  }

  IconData get icon {
    switch (this) {
      case PermissionType.camera:
        return Icons.camera_alt_rounded;
      case PermissionType.gallery:
        return Icons.photo_library_rounded;
      case PermissionType.location:
        return Icons.location_on_rounded;
      case PermissionType.notifications:
        return Icons.notifications_active_rounded;
    }
  }
}

class PermissionHelper {
  static const String _kPermissionPrefix = 'solar_perm_granted_';

  /// Check whether a permission was previously acknowledged/granted
  static Future<bool> checkPermission(PermissionType type) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_kPermissionPrefix${type.name}') ?? false;
  }

  /// Request permission with an interactive rationale explanation dialog
  static Future<bool> requestPermission(BuildContext context, PermissionType type) async {
    final alreadyGranted = await checkPermission(type);
    if (alreadyGranted) return true;

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy800,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.navy600),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.gold500.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(type.icon, color: AppColors.gold500, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                type.title,
                style: const TextStyle(
                  color: AppColors.fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              type.rationale,
              style: const TextStyle(
                color: AppColors.grey300,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.navy900,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppColors.teal500, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your data is encrypted and strictly used for field operations.',
                      style: TextStyle(color: AppColors.grey400, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Not Now', style: TextStyle(color: AppColors.grey500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold500,
              foregroundColor: AppColors.ink900,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text('Grant Access', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_kPermissionPrefix${type.name}', true);
      return true;
    }
    return false;
  }
}
