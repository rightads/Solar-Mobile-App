import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/kedl/data/models/kedl_model.dart';

class KedlFileCard extends StatelessWidget {
  final KedlFileModel file;
  final VoidCallback onTap;

  const KedlFileCard({
    super.key,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.navy700.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: file.hasOverdueDemand
              ? AppColors.error.withValues(alpha: 0.5)
              : (file.hasOpenDemand
                  ? AppColors.warning.withValues(alpha: 0.4)
                  : AppColors.navy600),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // File Type Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: file.fileType.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(file.fileType.icon, size: 20, color: file.fileType.color),
                ),
                const SizedBox(width: 12),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            file.fileType.displayName,
                            style: const TextStyle(
                              color: AppColors.fg,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: file.status.color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              file.status.displayName.toUpperCase(),
                              style: TextStyle(
                                color: file.status.color,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        file.applicationNo?.isNotEmpty == true
                            ? 'App #: ${file.applicationNo!}'
                            : 'No application # yet',
                        style: const TextStyle(
                          color: AppColors.grey400,
                          fontSize: 12,
                        ),
                      ),
                      if (file.submittedOn != null || file.hasOpenDemand) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (file.submittedOn != null) ...[
                              const Icon(Icons.calendar_today, size: 12, color: AppColors.grey400),
                              const SizedBox(width: 4),
                              Text(
                                'Sub: ${dateFormat.format(file.submittedOn!)}',
                                style: const TextStyle(color: AppColors.grey400, fontSize: 11),
                              ),
                            ],
                            const Spacer(),
                            if (file.hasOverdueDemand)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.error_outline, size: 11, color: AppColors.error),
                                    SizedBox(width: 3),
                                    Text(
                                      'OVERDUE DEMAND',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (file.hasOpenDemand)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: const Text(
                                  'OPEN DEMAND',
                                  style: TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.grey500),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
