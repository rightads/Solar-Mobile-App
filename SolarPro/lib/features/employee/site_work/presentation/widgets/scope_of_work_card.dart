import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/work_assignment/data/models/site_customer_scope.dart';
import 'package:solar_pro/features/work_assignment/data/models/work_assignment_model.dart';

class ScopeOfWorkCard extends StatelessWidget {
  final WorkType workType;
  final SiteCustomerScope scope;

  const ScopeOfWorkCard({
    super.key,
    required this.workType,
    required this.scope,
  });

  @override
  Widget build(BuildContext context) {
    final entries = scope.getEntriesForRole(workType);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.navy700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: workType.color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
              border: Border(
                bottom: BorderSide(color: AppColors.navy700),
              ),
            ),
            child: Row(
              children: [
                Icon(workType.icon, size: 18, color: workType.color),
                const SizedBox(width: 8),
                Text(
                  'Scope of Work (${workType.displayName})',
                  style: TextStyle(
                    color: workType.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.navy700,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Text(
                    'Technical Spec',
                    style: TextStyle(
                      color: AppColors.grey400,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Technical Specification List
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4, right: 10),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: workType.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          entry.key,
                          style: const TextStyle(
                            color: AppColors.grey400,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            color: AppColors.fg,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
