import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class UnsupportedRoleScreen extends StatelessWidget {
  final String? role;

  const UnsupportedRoleScreen({super.key, this.role});

  Future<void> _logout(BuildContext context) async {
    await ApiClient().logout();
    if (context.mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy900,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_person_rounded,
                  color: AppColors.error,
                  size: 56,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Account Not Supported',
                style: AppTextStyles.headlineLarge.copyWith(
                  color: AppColors.fg,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 12),
              Text(
                role != null && role!.isNotEmpty
                    ? 'The assigned role "$role" is not configured for this portal application.'
                    : 'Your account role is not supported on this device. Please contact your system administrator.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.grey400,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('Log Out'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.navy700,
                    foregroundColor: AppColors.fg,
                    side: const BorderSide(color: AppColors.navy600),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
