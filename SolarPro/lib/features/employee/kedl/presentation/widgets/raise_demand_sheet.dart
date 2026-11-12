import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/kedl/data/models/kedl_model.dart';
import 'package:solar_pro/features/kedl/data/repositories/kedl_repository.dart';

class RaiseDemandSheet extends StatefulWidget {
  final KedlFileModel file;
  final KedlRepository repository;
  final Function(KedlDemandModel) onDemandRaised;

  const RaiseDemandSheet({
    super.key,
    required this.file,
    required this.repository,
    required this.onDemandRaised,
  });

  @override
  State<RaiseDemandSheet> createState() => _RaiseDemandSheetState();
}

class _RaiseDemandSheetState extends State<RaiseDemandSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _selectedDueDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 180)),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold500,
            onPrimary: AppColors.navy900,
            surface: AppColors.navy800,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _selectedDueDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    int? amountPaise;
    final amountText = _amountController.text.trim();
    if (amountText.isNotEmpty) {
      final parsed = double.tryParse(amountText);
      if (parsed != null && parsed >= 0) {
        amountPaise = (parsed * 100).round();
      }
    }

    try {
      final demand = await widget.repository.raiseDemand(
        widget.file.id,
        description: _descController.text.trim(),
        amountPaise: amountPaise,
        dueDate: _selectedDueDate,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onDemandRaised(demand);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error raising demand: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
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

            // Header
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppColors.gold500, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Raise Discom Demand (${widget.file.fileType.displayName})',
                  style: const TextStyle(color: AppColors.fg, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Customer: ${widget.file.customerName}',
              style: const TextStyle(color: AppColors.grey400, fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Description Field
            TextFormField(
              controller: _descController,
              style: const TextStyle(color: AppColors.fg, fontSize: 14),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Demand Description / Requirement *',
                labelStyle: const TextStyle(color: AppColors.grey400),
                hintText: 'e.g. Net meter testing fee or additional inspection demand note',
                hintStyle: TextStyle(color: AppColors.grey600),
                filled: true,
                fillColor: AppColors.navy700,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 3) {
                  return 'Please enter a description (at least 3 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Amount Field
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.fg, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Fee Amount in Rupees (Optional)',
                labelStyle: const TextStyle(color: AppColors.grey400),
                prefixText: '₹ ',
                prefixStyle: const TextStyle(color: AppColors.gold500, fontWeight: FontWeight.bold),
                hintText: 'e.g. 2500',
                hintStyle: TextStyle(color: AppColors.grey600),
                filled: true,
                fillColor: AppColors.navy700,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            // Due Date Selector
            InkWell(
              onTap: _pickDueDate,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.navy700,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.gold500),
                    const SizedBox(width: 10),
                    Text(
                      _selectedDueDate != null
                          ? 'Due Date: ${dateFormat.format(_selectedDueDate!)}'
                          : 'Select Payment Due Date (Optional)',
                      style: TextStyle(
                        color: _selectedDueDate != null ? AppColors.fg : AppColors.grey400,
                        fontSize: 13,
                        fontWeight: _selectedDueDate != null ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: AppColors.grey400),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.shadow))
                    : const Icon(Icons.add_task_rounded),
                label: const Text('Raise Demand & Set Status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold500,
                  foregroundColor: AppColors.ink900,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
