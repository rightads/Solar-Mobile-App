import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/client/data/models/client_dashboard_model.dart';
import 'package:solar_pro/features/client/presentation/widgets/submit_payment_modal.dart';

class ClientPaymentsTab extends StatelessWidget {
  final Map<String, dynamic>? paymentSummary;
  final List<ClientPaymentRecord> payments;
  final AssignedEmployeeInfo? salesRep;
  final Function(ClientPaymentRecord) onPaymentSubmitted;

  const ClientPaymentsTab({
    super.key,
    required this.paymentSummary,
    required this.payments,
    required this.salesRep,
    required this.onPaymentSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final totalAmount = (paymentSummary?['total_amount'] as num?)?.toDouble() ?? 0.0;
    final totalPaid = (paymentSummary?['total_paid'] as num?)?.toDouble() ?? 0.0;
    final remaining = (paymentSummary?['remaining_balance'] as num?)?.toDouble() ?? (totalAmount - totalPaid);
    final nextMilestone = paymentSummary?['next_milestone']?.toString() ?? 'Awaiting Project Quote';

    final hasSalesRep = salesRep != null && salesRep!.name.isNotEmpty;
    final salesName = hasSalesRep ? salesRep!.name : 'Sales Representative';
    final salesEmpNo = hasSalesRep ? salesRep!.employeeNo : '';

    return RefreshIndicator(
      onRefresh: () async {},
      color: AppColors.gold500,
      backgroundColor: AppColors.navy800,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Financial Summary Card
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A6E), Color(0xFF0F2040)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.gold500.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Financial Overview', style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey300)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.gold500.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '${((totalPaid / totalAmount) * 100).toStringAsFixed(0)}% Paid',
                          style: AppTextStyles.caption.copyWith(color: AppColors.gold400, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('₹${totalPaid.toStringAsFixed(0)}',
                      style: AppTextStyles.displaySmall.copyWith(color: AppColors.gold400, fontWeight: FontWeight.bold)),
                  Text('Total Paid of ₹${totalAmount.toStringAsFixed(0)}',
                      style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
                  const SizedBox(height: 14),

                  // Balance & Next Due
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.navy900.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Remaining Balance', style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
                              const SizedBox(height: 2),
                              Text('₹${remaining.toStringAsFixed(0)}',
                                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.navy900.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Next Milestone Due', style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
                              const SizedBox(height: 2),
                              Text(nextMilestone,
                                  style: AppTextStyles.caption.copyWith(color: AppColors.gold400, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
          ),

          // REQUIREMENT 2 BANNER: "Payment Submit with Photo approved by Salesman"
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.navy800,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.gold500.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_rounded, color: AppColors.gold500, size: 20),
                        const SizedBox(width: 8),
                        Text('Salesman Approval Workflow',
                            style: AppTextStyles.labelLarge.copyWith(color: AppColors.white)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. You submit payment with photo receipt.\n'
                      '${hasSalesRep ? "2. Approved by assigned salesman: $salesName ($salesEmpNo).\n" : "2. Approved by assigned salesman.\n"}'
                      '3. Final verification & official receipt by Accounts Admin.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.grey300, height: 1.45),
                    ),
                    const SizedBox(height: 14),

                    // Primary Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold500,
                          foregroundColor: AppColors.navy900,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                        onPressed: () => SubmitPaymentModal.show(
                          context,
                          salesRep: salesRep,
                          onPaymentSubmitted: onPaymentSubmitted,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text('Submit Payment with Photo',
                                style: AppTextStyles.labelLarge.copyWith(color: AppColors.navy900, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 450.ms),
            ),
          ),

          // Payment History Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Payment Submissions & Approvals', style: AppTextStyles.headlineSmall),
                  Text('${payments.length} records', style: AppTextStyles.caption.copyWith(color: AppColors.grey500)),
                ],
              ),
            ),
          ),

          // Payment History List
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: payments.isEmpty
                ? SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            const Icon(Icons.receipt_long_rounded, color: AppColors.grey600, size: 48),
                            const SizedBox(height: 12),
                            Text('No payments submitted yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.grey400)),
                            const SizedBox(height: 6),
                            Text('Submit milestone payment with photo proof above.', style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final p = payments[i];
                        return _buildPaymentCard(context, p, salesName, salesEmpNo);
                      },
                      childCount: payments.length,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, ClientPaymentRecord p, String salesName, String salesEmpNo) {
    final hasSalesRep = salesEmpNo.isNotEmpty;
    Color statusColor;
    IconData statusIcon;
    String statusTitle;

    if (p.isVerified) {
      statusColor = AppColors.success;
      statusIcon = Icons.verified_rounded;
      statusTitle = 'Verified by Admin ✓';
    } else if (p.isSalesApproved) {
      statusColor = AppColors.teal400;
      statusIcon = Icons.check_circle_outline_rounded;
      statusTitle = 'Approved by Salesman';
    } else if (p.isRejected) {
      statusColor = AppColors.error;
      statusIcon = Icons.cancel_rounded;
      statusTitle = 'Payment Rejected';
    } else {
      statusColor = AppColors.gold500;
      statusIcon = Icons.hourglass_top_rounded;
      statusTitle = 'Pending Salesman Approval';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('₹${p.amount.toStringAsFixed(0)}',
                  style: AppTextStyles.headlineSmall.copyWith(color: AppColors.white, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 13),
                    const SizedBox(width: 4),
                    Text(
                      statusTitle,
                      style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(p.stageName, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.gold400)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('${p.mode} • ', style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
              if (p.referenceNo != null)
                Flexible(
                  child: Text(
                    'Ref: ${p.referenceNo} • ',
                    style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Text(
                '${p.paidOn.day}/${p.paidOn.month}/${p.paidOn.year}',
                style: AppTextStyles.caption.copyWith(color: AppColors.grey500),
              ),
            ],
          ),
          const Divider(color: AppColors.navy700, height: 16),

          // Photo receipt preview + Salesman approval state
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.navy800,
                      title: const Text('Payment Receipt Photo', style: TextStyle(color: Colors.white)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            height: 180,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.navy900,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.gold500.withValues(alpha: 0.4)),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_rounded, size: 54, color: AppColors.gold500),
                                SizedBox(height: 8),
                                Text('Receipt Verified Proof', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                Text('Official transaction upload', style: TextStyle(color: AppColors.grey400, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('Ref: ${p.referenceNo ?? 'UPI-TXN'}', style: const TextStyle(color: AppColors.gold400)),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Close', style: TextStyle(color: AppColors.gold500)),
                        ),
                      ],
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.navy900,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gold500.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined, color: AppColors.gold400, size: 14),
                      SizedBox(width: 4),
                      Text('View Photo Receipt', style: TextStyle(fontSize: 11, color: AppColors.gold400, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Approver Employee attribution
              if (p.isSalesApproved || p.isVerified)
                Expanded(
                  child: Text(
                    p.salesApprovedBy != null ? 'Approved by: ${p.salesApprovedBy}${p.salesApproverEmpNo != null ? " (${p.salesApproverEmpNo})" : ""}' : (hasSalesRep ? 'Approved by: $salesName ($salesEmpNo)' : 'Approved by Sales'),
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: AppColors.teal400, fontSize: 10),
                  ),
                )
              else if (p.isPendingSalesApproval)
                Expanded(
                  child: Text(
                    hasSalesRep ? 'Awaiting $salesName ($salesEmpNo)' : 'Awaiting Sales Approval',
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(color: AppColors.gold400, fontSize: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
