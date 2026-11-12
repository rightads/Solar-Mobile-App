import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/work_assignment/data/models/work_assignment_model.dart';

class SiteJobCard extends StatelessWidget {
  final WorkAssignmentModel job;
  final VoidCallback onTap;

  const SiteJobCard({
    super.key,
    required this.job,
    required this.onTap,
  });

  String _formatDateRange(DateTime start, DateTime end) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    if (startDate == today && endDate == today) {
      return 'Today';
    }
    final fmt = DateFormat('dd MMM');
    if (startDate == endDate) {
      return fmt.format(start);
    }
    return '${fmt.format(start)} - ${fmt.format(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDateRange(job.scheduledStart, job.scheduledEnd);
    final isToday = dateStr == 'Today';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: job.isPendingSync
              ? AppColors.warning.withValues(alpha: 0.4)
              : (job.status == WorkStatus.inProgress
                  ? AppColors.gold500.withValues(alpha: 0.3)
                  : AppColors.navy700),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Work Type pill & Status chip
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: job.workType.color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: job.workType.color.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(job.workType.icon, size: 14, color: job.workType.color),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                job.workType.displayName.toUpperCase(),
                                style: TextStyle(
                                  color: job.workType.color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (job.isPendingSync) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sync_problem_rounded, size: 12, color: AppColors.warning),
                            SizedBox(width: 4),
                            Text(
                              'PENDING SYNC',
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: job.status.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        job.status.displayName.toUpperCase(),
                        style: TextStyle(
                          color: job.status.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Customer Name
                Text(
                  job.customer?.name ?? 'Customer Assignment',
                  style: const TextStyle(
                    color: AppColors.fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),

                // Customer Area / Address
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 15, color: AppColors.grey400),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        job.customer?.address.isNotEmpty == true
                            ? job.customer!.address
                            : 'Site Location Not Specified',
                        style: const TextStyle(
                          color: AppColors.grey400,
                          fontSize: 13,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom row: Scheduled Dates & Photos count
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.navy700.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: isToday ? AppColors.gold500 : AppColors.grey400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: TextStyle(
                          color: isToday ? AppColors.gold500 : AppColors.fg,
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.photo_library_outlined, size: 14, color: AppColors.grey400),
                      const SizedBox(width: 5),
                      Text(
                        '${job.photos.length} photos',
                        style: const TextStyle(
                          color: AppColors.grey300,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.grey400),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
