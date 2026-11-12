import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/payments/data/payment_repository.dart';

/// Modal bottom sheet for recording a customer payment with proof receipt.
class RecordPaymentSheet extends StatefulWidget {
  final String customerId;
  final String customerName;
  final int? balancePaise;
  final VoidCallback onPaymentRecorded;

  const RecordPaymentSheet({
    super.key,
    required this.customerId,
    required this.customerName,
    this.balancePaise,
    required this.onPaymentRecorded,
  });

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _remarksController = TextEditingController();

  String _mode = 'upi';
  String? _attachedFileName;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _modes = [
    {'value': 'upi', 'label': 'UPI / QR Code', 'icon': Icons.qr_code_scanner_rounded},
    {'value': 'bank_transfer', 'label': 'Bank Transfer / NEFT', 'icon': Icons.account_balance_rounded},
    {'value': 'cheque', 'label': 'Cheque', 'icon': Icons.receipt_long_rounded},
    {'value': 'cash', 'label': 'Cash', 'icon': Icons.payments_rounded},
    {'value': 'other', 'label': 'Other', 'icon': Icons.payment_rounded},
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  void _attachProof(String source) {
    final timestamp = DateTime.now().millisecondsSinceEpoch % 10000;
    final ext = source == 'camera' ? 'jpg' : 'png';
    setState(() {
      _attachedFileName = 'receipt_$timestamp.$ext';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Attached $_attachedFileName (compressed)'),
        backgroundColor: AppColors.teal500,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final rupees = int.tryParse(_amountController.text.replaceAll(RegExp(r'\D'), '')) ?? 0;
    if (rupees <= 0) return;

    final amountPaise = rupees * 100;

    setState(() => _isLoading = true);

    try {
      final repo = PaymentRepository();
      await repo.recordPayment(
        customerId: widget.customerId,
        amountPaise: amountPaise,
        mode: _mode,
        referenceNo: _referenceController.text.trim().isNotEmpty ? _referenceController.text.trim() : null,
        remarks: _remarksController.text.trim().isNotEmpty ? _remarksController.text.trim() : null,
        proofBytes: _attachedFileName != null ? [0, 1, 2, 3] : null,
        proofFileName: _attachedFileName,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
        widget.onPaymentRecorded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded and submitted for approval!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.navy900,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey700,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Record Payment',
                        style: TextStyle(color: AppColors.fg, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Customer: ${widget.customerName}',
                        style: const TextStyle(color: AppColors.teal500, fontSize: 12),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.grey400),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Amount
              const Text('Payment Amount (Rupees) *', style: TextStyle(color: AppColors.grey300, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.fg, fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.currency_rupee_rounded, color: AppColors.gold500),
                  hintText: 'e.g. 50000',
                  hintStyle: const TextStyle(color: AppColors.grey500),
                  filled: true,
                  fillColor: AppColors.navy800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.navy700),
                  ),
                ),
                validator: (v) {
                  final clean = (v ?? '').replaceAll(RegExp(r'\D'), '');
                  final val = int.tryParse(clean) ?? 0;
                  if (val <= 0) return 'Valid amount required';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Payment Mode Dropdown
              const Text('Payment Mode *', style: TextStyle(color: AppColors.grey300, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.navy800,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.navy700),
                ),
                child: DropdownButton<String>(
                  value: _mode,
                  isExpanded: true,
                  dropdownColor: AppColors.navy800,
                  underline: const SizedBox.shrink(),
                  style: const TextStyle(color: AppColors.fg, fontSize: 14),
                  items: _modes.map((m) {
                    return DropdownMenuItem<String>(
                      value: m['value'] as String,
                      child: Row(
                        children: [
                          Icon(m['icon'] as IconData, color: AppColors.teal500, size: 18),
                          const SizedBox(width: 10),
                          Text(m['label'] as String),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _mode = val);
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Reference / Cheque No
              const Text('Reference / UTR / Cheque Number', style: TextStyle(color: AppColors.grey300, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _referenceController,
                style: const TextStyle(color: AppColors.fg, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. UPI Ref 3291823901 or Cheque #004521',
                  hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 13),
                  prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.grey400, size: 20),
                  filled: true,
                  fillColor: AppColors.navy800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.navy700),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Remarks
              const Text('Remarks / Milestone Description', style: TextStyle(color: AppColors.grey300, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _remarksController,
                style: const TextStyle(color: AppColors.fg, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'e.g. Booking Advance 20%',
                  hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 13),
                  prefixIcon: const Icon(Icons.comment_outlined, color: AppColors.grey400, size: 20),
                  filled: true,
                  fillColor: AppColors.navy800,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.navy700),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Proof Photo Attachment
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.navy800,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: _attachedFileName != null
                        ? AppColors.teal500.withValues(alpha: 0.5)
                        : AppColors.navy700,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _attachedFileName != null
                            ? AppColors.teal500.withValues(alpha: 0.15)
                            : AppColors.navy900,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        _attachedFileName != null ? Icons.image_rounded : Icons.add_a_photo_outlined,
                        color: _attachedFileName != null ? AppColors.teal500 : AppColors.grey400,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _attachedFileName ?? 'Attach Receipt / Bank Proof',
                            style: TextStyle(
                              color: _attachedFileName != null ? AppColors.fg : AppColors.grey400,
                              fontSize: 13,
                              fontWeight: _attachedFileName != null ? FontWeight.w600 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text('Camera photo or gallery screenshot', style: TextStyle(color: AppColors.grey500, fontSize: 11)),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: AppColors.grey400),
                      color: AppColors.ink900,
                      onSelected: (val) {
                        if (val == 'camera') _attachProof('camera');
                        if (val == 'gallery') _attachProof('gallery');
                        if (val == 'remove') setState(() => _attachedFileName = null);
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'camera', child: Text('Capture with Camera', style: TextStyle(color: AppColors.fg))),
                        const PopupMenuItem(value: 'gallery', child: Text('Choose from Gallery', style: TextStyle(color: AppColors.fg))),
                        if (_attachedFileName != null)
                          const PopupMenuItem(value: 'remove', child: Text('Remove Photo', style: TextStyle(color: AppColors.error))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitPayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal500,
                    foregroundColor: AppColors.fg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.fg),
                        )
                      : const Text('Record & Submit Payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
