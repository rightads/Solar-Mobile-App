import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/kedl/data/models/kedl_model.dart';

class KedlDemandCard extends StatelessWidget {
  final KedlDemandModel demand;
  final VoidCallback? onMarkPaid;
  final VoidCallback? onWaive;

  const KedlDemandCard({
    super.key,
    required this.demand,
    this.onMarkPaid,
    this.onWaive,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final isOverdue = demand.isOverdue;
    final isActionable = demand.status == KedlDemandStatus.open;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isOverdue
              ? AppColors.error
              : (demand.status == KedlDemandStatus.open
                  ? AppColors.warning.withValues(alpha: 0.5)
                  : AppColors.navy700),
          width: isOverdue ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overdue Banner if overdue
          if (isOverdue)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: const BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg - 1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.fg, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'OVERDUE DEMAND - ACTION REQUIRED',
                    style: TextStyle(
                      color: AppColors.fg,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Customer Name & Status Chip
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        demand.customerName,
                        style: const TextStyle(
                          color: AppColors.fg,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: demand.status.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        demand.status.displayName.toUpperCase(),
                        style: TextStyle(
                          color: demand.status.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  demand.description,
                  style: const TextStyle(
                    color: AppColors.grey300,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Amount & Due Date Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.navy700.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      if (demand.amountPaise != null) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Amount Required', style: TextStyle(color: AppColors.grey400, fontSize: 11)),
                            const SizedBox(height: 2),
                            Text(
                              '₹ ${demand.amountRupees.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: isOverdue ? AppColors.error : AppColors.gold500,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                      ],
                      if (demand.dueDate != null) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              isOverdue ? 'Overdue Since' : 'Due Date',
                              style: TextStyle(
                                color: isOverdue ? AppColors.error : AppColors.grey400,
                                fontSize: 11,
                                fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.event,
                                  size: 14,
                                  color: isOverdue ? AppColors.error : AppColors.fg,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  dateFormat.format(demand.dueDate!),
                                  style: TextStyle(
                                    color: isOverdue ? AppColors.error : AppColors.fg,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Paid On Info
                if (demand.paidOn != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.success, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Resolved on ${dateFormat.format(demand.paidOn!)}',
                        style: const TextStyle(color: AppColors.success, fontSize: 12),
                      ),
                      if (demand.receiptKey != null) ...[
                        const Spacer(),
                        const Icon(Icons.receipt_long, color: AppColors.gold500, size: 14),
                        const SizedBox(width: 4),
                        const Text(
                          'Receipt Attached',
                          style: TextStyle(color: AppColors.gold500, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ],

                // Action Buttons for Open Demand
                if (isActionable && (onMarkPaid != null || onWaive != null)) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (onWaive != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onWaive,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.grey400,
                              side: const BorderSide(color: AppColors.navy600),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: const Text('Waive Demand'),
                          ),
                        ),
                      if (onWaive != null && onMarkPaid != null) const SizedBox(width: 10),
                      if (onMarkPaid != null)
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: onMarkPaid,
                            icon: const Icon(Icons.check_circle, size: 16),
                            label: const Text('Mark as Paid'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: AppColors.fg,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
