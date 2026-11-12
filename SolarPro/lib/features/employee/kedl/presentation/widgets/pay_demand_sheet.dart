import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/kedl/data/models/kedl_model.dart';
import 'package:solar_pro/features/kedl/data/repositories/kedl_repository.dart';

class PayDemandSheet extends StatefulWidget {
  final KedlDemandModel demand;
  final KedlRepository repository;
  final Function(KedlDemandModel) onDemandUpdated;

  const PayDemandSheet({
    super.key,
    required this.demand,
    required this.repository,
    required this.onDemandUpdated,
  });

  @override
  State<PayDemandSheet> createState() => _PayDemandSheetState();
}

class _PayDemandSheetState extends State<PayDemandSheet> {
  KedlDemandStatus _status = KedlDemandStatus.paid;
  bool _hasReceipt = false;
  String? _receiptName;
  bool _isSubmitting = false;

  void _pickReceipt() {
    setState(() {
      _hasReceipt = true;
      _receiptName = 'demand_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
    });
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final updated = await widget.repository.updateDemand(
        widget.demand.id,
        status: _status,
        paidOn: _status == KedlDemandStatus.paid ? DateTime.now() : null,
        receiptFilePath: _hasReceipt ? _receiptName : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onDemandUpdated(updated);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating demand: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Row(
            children: [
              Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 22),
              SizedBox(width: 8),
              Text(
                'Resolve Discom Demand',
                style: TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.demand.description,
            style: const TextStyle(color: AppColors.grey300, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.demand.amountPaise != null) ...[
            const SizedBox(height: 6),
            Text(
              'Amount: ₹ ${widget.demand.amountRupees.toStringAsFixed(0)}',
              style: const TextStyle(color: AppColors.gold500, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
          const SizedBox(height: 16),

          // Resolution Action Toggle
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Mark as Paid')),
                  selected: _status == KedlDemandStatus.paid,
                  onSelected: (val) {
                    if (val) setState(() => _status = KedlDemandStatus.paid);
                  },
                  selectedColor: AppColors.success,
                  labelStyle: TextStyle(
                    color: _status == KedlDemandStatus.paid ? AppColors.fg : AppColors.grey400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('Waive Demand')),
                  selected: _status == KedlDemandStatus.waived,
                  onSelected: (val) {
                    if (val) setState(() => _status = KedlDemandStatus.waived);
                  },
                  selectedColor: AppColors.navy600,
                  labelStyle: TextStyle(
                    color: _status == KedlDemandStatus.waived ? AppColors.fg : AppColors.grey400,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Optional Receipt for Paid
          if (_status == KedlDemandStatus.paid) ...[
            InkWell(
              onTap: _pickReceipt,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.navy700,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: _hasReceipt ? AppColors.success : AppColors.navy600,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _hasReceipt ? Icons.receipt_long : Icons.add_photo_alternate_outlined,
                      color: _hasReceipt ? AppColors.success : AppColors.gold500,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _hasReceipt ? 'Receipt Attached' : 'Attach Payment Receipt (Optional)',
                            style: TextStyle(
                              color: _hasReceipt ? AppColors.fg : AppColors.grey300,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (_receiptName != null)
                            Text(
                              _receiptName!,
                              style: const TextStyle(color: AppColors.grey400, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    if (_hasReceipt)
                      const Icon(Icons.check, color: AppColors.success, size: 18)
                    else
                      const Icon(Icons.upload_file, color: AppColors.grey400, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _status == KedlDemandStatus.paid ? AppColors.success : AppColors.navy600,
                foregroundColor: AppColors.fg,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.fg))
                  : Text(_status == KedlDemandStatus.paid ? 'Confirm Payment & Resolve' : 'Confirm Demand Waiver'),
            ),
          ),
        ],
      ),
    );
  }
}
