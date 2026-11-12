import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class EmployeeEmptyPlaceholder extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const EmployeeEmptyPlaceholder({
    super.key,
    required this.title,
    required this.description,
    this.icon = Icons.construction_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.gold500.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.gold500, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineMedium.copyWith(
                color: AppColors.fg,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.grey400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
