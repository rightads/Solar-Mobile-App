import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/payments/data/models/payment_model.dart';

/// Card for customer-submitted payments awaiting salesman approval.
class PendingApprovalCard extends StatelessWidget {
  final PaymentModel payment;
  final VoidCallback onApprove;
  final ValueChanged<String> onReject;

  const PendingApprovalCard({
    super.key,
    required this.payment,
    required this.onApprove,
    required this.onReject,
  });

  void _showProofPhoto(BuildContext context) {
    if (payment.proofUrl == null || payment.proofUrl!.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: AppColors.fg, size: 28),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.network(
                payment.proofUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  padding: const EdgeInsets.all(24),
                  color: AppColors.navy800,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_rounded, color: AppColors.grey500, size: 48),
                      SizedBox(height: 8),
                      Text('Proof image not available', style: TextStyle(color: AppColors.fg)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navy800,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Reject Payment', style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rejecting submission for ${payment.formattedAmountRupees}. A clear reason is required for the client.',
                style: const TextStyle(color: AppColors.grey300, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(color: AppColors.fg, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. UTR reference not matching bank statement, incorrect amount...',
                  hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 12),
                  filled: true,
                  fillColor: AppColors.navy900,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.navy700),
                  ),
                ),
                validator: (v) => (v == null || v.trim().length < 3)
                    ? 'Please provide a reason (min 3 chars)'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.grey400)),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final reason = reasonController.text.trim();
                Navigator.of(ctx).pop();
                onReject(reason);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.fg,
            ),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSalesApproved = payment.status.toLowerCase() == 'sales_approved';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy800,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isSalesApproved ? AppColors.info.withValues(alpha: 0.5) : AppColors.navy700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Amount & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                payment.formattedAmountRupees,
                style: const TextStyle(
                  color: AppColors.gold500,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: payment.statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: payment.statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  payment.statusLabel,
                  style: TextStyle(
                    color: payment.statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Customer ID & Date
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, color: AppColors.grey400, size: 14),
              const SizedBox(width: 4),
              Text(
                'Customer: ${payment.customerId.length > 8 ? payment.customerId.substring(0, 8).toUpperCase() : payment.customerId}',
                style: const TextStyle(color: AppColors.grey300, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              const Icon(Icons.event_rounded, color: AppColors.grey500, size: 14),
              const SizedBox(width: 4),
              Text(
                payment.formattedPaidDate,
                style: const TextStyle(color: AppColors.grey400, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Mode & Reference
          Row(
            children: [
              Icon(payment.modeIcon, color: AppColors.teal500, size: 14),
              const SizedBox(width: 4),
              Text(
                payment.modeLabel,
                style: const TextStyle(color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w500),
              ),
              if (payment.referenceNo != null && payment.referenceNo!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  'Ref: ${payment.referenceNo}',
                  style: const TextStyle(color: AppColors.grey400, fontSize: 12),
                ),
              ],
            ],
          ),

          if (payment.remarks != null && payment.remarks!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Remarks: "${payment.remarks}"',
              style: const TextStyle(color: AppColors.grey400, fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ],
          const Divider(color: AppColors.navy700, height: 20),

          // Proof photo preview button & Actions
          Row(
            children: [
              if (payment.proofUrl != null && payment.proofUrl!.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _showProofPhoto(context),
                  icon: const Icon(Icons.image_rounded, color: AppColors.teal500, size: 16),
                  label: const Text('View Receipt', style: TextStyle(color: AppColors.teal500, fontSize: 12)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                )
              else
                const Text('No photo attached', style: TextStyle(color: AppColors.grey500, fontSize: 11)),
              const Spacer(),

              if (!isSalesApproved && payment.status.toLowerCase() == 'pending') ...[
                OutlinedButton(
                  onPressed: () => _showRejectDialog(context),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: AppColors.error),
                    foregroundColor: AppColors.error,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Sales Approve'),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: AppColors.teal500,
                    foregroundColor: AppColors.fg,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ] else if (isSalesApproved) ...[
                const Icon(Icons.hourglass_top_rounded, color: AppColors.info, size: 14),
                const SizedBox(width: 4),
                const Text(
                  'Waiting for Admin to verify funds',
                  style: TextStyle(color: AppColors.info, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
