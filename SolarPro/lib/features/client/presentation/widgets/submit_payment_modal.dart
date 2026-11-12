import 'package:flutter/material.dart';
import 'package:solar_pro/core/services/media_picker.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/client/data/models/client_dashboard_model.dart';
import 'package:solar_pro/features/client/data/repositories/client_repository.dart';

class SubmitPaymentModal extends StatefulWidget {
  final AssignedEmployeeInfo? salesRep;
  final Function(ClientPaymentRecord) onPaymentSubmitted;

  const SubmitPaymentModal({
    super.key,
    this.salesRep,
    required this.onPaymentSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    AssignedEmployeeInfo? salesRep,
    required Function(ClientPaymentRecord) onPaymentSubmitted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: SubmitPaymentModal(
          salesRep: salesRep,
          onPaymentSubmitted: onPaymentSubmitted,
        ),
      ),
    );
  }

  @override
  State<SubmitPaymentModal> createState() => _SubmitPaymentModalState();
}

class _SubmitPaymentModalState extends State<SubmitPaymentModal> {
  final _amountCtrl = TextEditingController(text: '50000');
  final _refCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  String _selectedMode = 'UPI';
  final List<String> _modes = ['UPI', 'Net Banking', 'Cheque', 'Bank Transfer', 'Cash'];

  bool _isSubmitting = false;
  String? _selectedPhotoName;
  bool _hasPhoto = false;
  PickedMedia? _proof;

  final _clientRepo = ClientRepository();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSamplePhoto() async {
    try {
      final picked = await MediaPicker.pickPhotos(context);
      if (picked.isEmpty || !mounted) return;
      setState(() {
        _proof = picked.first;
        _hasPhoto = true;
        _selectedPhotoName = picked.first.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', '')), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _submit() async {
    final amtText = _amountCtrl.text.trim();
    final amount = double.tryParse(amtText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid payment amount in ₹'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (!_hasPhoto) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please attach photo proof / screenshot of payment for salesman approval'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final record = await _clientRepo.submitPayment(
        amountRupees: amount,
        mode: _selectedMode,
        referenceNo: _refCtrl.text.trim().isNotEmpty ? _refCtrl.text.trim() : null,
        remarks: _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
        proof: _proof,
      );

      if (mounted) {
        widget.onPaymentSubmitted(record);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.salesRep != null && widget.salesRep!.name.isNotEmpty
                        ? 'Payment of ₹${amount.toStringAsFixed(0)} submitted! Awaiting approval by ${widget.salesRep!.name}.'
                        : 'Payment of ₹${amount.toStringAsFixed(0)} submitted! Awaiting approval by your sales representative.',
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit payment: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesRepName = widget.salesRep?.name ?? 'your sales representative';
    final salesEmpNo = widget.salesRep?.employeeNo ?? '';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey600,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title & Workflow note
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold500.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.gold500, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Submit Payment with Photo', style: AppTextStyles.headlineMedium),
                    Text('Approved by Salesman before Admin verification',
                        style: AppTextStyles.caption.copyWith(color: AppColors.gold400)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Approval workflow explainer banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.navy700,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.gold500.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.gold400, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: AppTextStyles.caption.copyWith(color: AppColors.grey300, height: 1.4),
                      children: [
                        const TextSpan(text: 'Assigned Salesman: '),
                        TextSpan(
                          text: '$salesRepName ($salesEmpNo)',
                          style: const TextStyle(color: AppColors.gold400, fontWeight: FontWeight.bold),
                        ),
                        const TextSpan(
                          text: '\nYour payment will be submitted in "Pending Salesman Approval" status and verified by your representative.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Amount Input
          Text('Payment Amount (₹)', style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey300)),
          const SizedBox(height: 6),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            style: AppTextStyles.headlineSmall.copyWith(color: AppColors.fg),
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixStyle: AppTextStyles.headlineSmall.copyWith(color: AppColors.gold500),
              hintText: 'Enter amount (e.g. 50000)',
              hintStyle: const TextStyle(color: AppColors.grey500),
              filled: true,
              fillColor: AppColors.navy900,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.navy600),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.navy600),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.gold500),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Preset amount buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [25000, 50000, 75000, 100000].map((preset) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: AppColors.navy700,
                    side: BorderSide(color: AppColors.gold500.withValues(alpha: 0.3)),
                    label: Text('₹${preset ~/ 1000}k', style: AppTextStyles.caption.copyWith(color: AppColors.gold400)),
                    onPressed: () => setState(() => _amountCtrl.text = preset.toString()),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Payment Mode
          Text('Payment Mode', style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey300)),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _modes.map((mode) {
                final isSelected = _selectedMode == mode;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(mode),
                    selected: isSelected,
                    selectedColor: AppColors.gold500,
                    backgroundColor: AppColors.navy900,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.navy900 : AppColors.grey300,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (val) {
                      if (val) setState(() => _selectedMode = mode);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Reference Number / UTR
          Text('Transaction Reference / UTR / Cheque No.', style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey300)),
          const SizedBox(height: 6),
          TextField(
            controller: _refCtrl,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
            decoration: InputDecoration(
              hintText: 'e.g. UPI/4891238910 or Cheque #000412',
              hintStyle: const TextStyle(color: AppColors.grey500),
              prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.grey400, size: 20),
              filled: true,
              fillColor: AppColors.navy900,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.navy600),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.navy600),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.gold500),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Photo Upload Section (MANDATORY REQUIREMENT: "Payment Submit with Photo")
          Text('Upload Payment Receipt / Proof Photo *',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.gold400, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickSamplePhoto,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _hasPhoto ? AppColors.success.withValues(alpha: 0.1) : AppColors.navy900,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: _hasPhoto ? AppColors.success : AppColors.gold500.withValues(alpha: 0.5),
                  style: BorderStyle.solid,
                  width: 1.5,
                ),
              ),
              child: _hasPhoto
                  ? Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.receipt_rounded, color: AppColors.success, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Receipt Photo Attached ✓',
                                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.success)),
                              Text(_selectedPhotoName ?? 'receipt.jpg',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.grey300),
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: AppColors.gold500, size: 20),
                          tooltip: 'Change Photo',
                          onPressed: _pickSamplePhoto,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.error, size: 20),
                          tooltip: 'Remove',
                          onPressed: () => setState(() {
                            _hasPhoto = false;
                            _selectedPhotoName = null;
                            _proof = null;
                          }),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt_rounded, color: AppColors.gold500, size: 22),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Attach Receipt / Screenshot Photo',
                                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.gold400, fontWeight: FontWeight.bold)),
                            Text('Required for salesman approval (Camera / Gallery)',
                                style: AppTextStyles.caption.copyWith(color: AppColors.grey400)),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Remarks
          Text('Remarks / Milestone Note (Optional)', style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey300)),
          const SizedBox(height: 6),
          TextField(
            controller: _remarksCtrl,
            maxLines: 2,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
            decoration: InputDecoration(
              hintText: 'e.g. Paid token for Structure & Electrical milestone',
              hintStyle: const TextStyle(color: AppColors.grey500),
              filled: true,
              fillColor: AppColors.navy900,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.navy600),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.navy600),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.gold500),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold500,
                foregroundColor: AppColors.ink900,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: AppColors.ink900, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text('Submit for Salesman Approval', style: AppTextStyles.labelLarge.copyWith(color: AppColors.ink900, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
