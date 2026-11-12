import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/features/leads/data/lead_repository.dart';
import 'package:solar_pro/features/leads/data/models/lead_model.dart';

class AddLeadBottomSheet extends StatefulWidget {
  final VoidCallback? onSuccess;

  const AddLeadBottomSheet({super.key, this.onSuccess});

  static Future<LeadModel?> show(BuildContext context) {
    return showModalBottomSheet<LeadModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy900,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => const AddLeadBottomSheet(),
    );
  }

  @override
  State<AddLeadBottomSheet> createState() => _AddLeadBottomSheetState();
}

class _AddLeadBottomSheetState extends State<AddLeadBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _kwController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _kwController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = LeadRepository();
      final double? kw = _kwController.text.trim().isNotEmpty
          ? double.tryParse(_kwController.text.trim())
          : null;

      final newLead = await repo.createLead(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
        expectedKw: kw,
        reference: _referenceController.text.trim().isNotEmpty ? _referenceController.text.trim() : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (mounted) {
        widget.onSuccess?.call();
        Navigator.of(context).pop(newLead);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
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
                    color: AppColors.navy600,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add New Lead',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.grey400),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Capture prospect details. Will be auto-assigned to you.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.fg, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.fg),
                decoration: const InputDecoration(
                  labelText: 'Customer Full Name *',
                  hintText: 'e.g. Ramesh Patel',
                  prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.gold500),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 2) {
                    return 'Please enter customer name (at least 2 chars)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: AppColors.fg),
                decoration: const InputDecoration(
                  labelText: '10-Digit Mobile Number *',
                  hintText: '9876543210',
                  prefixIcon: Icon(Icons.phone_outlined, color: AppColors.gold500),
                  prefixText: '+91 ',
                ),
                validator: (val) {
                  final clean = val?.replaceAll(RegExp(r'\D'), '') ?? '';
                  if (clean.length != 10) {
                    return 'Enter valid 10-digit Indian mobile number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressController,
                style: const TextStyle(color: AppColors.fg),
                decoration: const InputDecoration(
                  labelText: 'Address / Area',
                  hintText: 'e.g. Ward 4, Civil Lines, Kota',
                  prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.gold500),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _kwController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: AppColors.fg),
                      decoration: const InputDecoration(
                        labelText: 'Expected kW',
                        hintText: 'e.g. 5.0',
                        prefixIcon: Icon(Icons.bolt_rounded, color: AppColors.gold500),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _referenceController,
                      style: const TextStyle(color: AppColors.fg),
                      decoration: const InputDecoration(
                        labelText: 'Reference / Source',
                        hintText: 'e.g. Friend, Flyer',
                        prefixIcon: Icon(Icons.tag_rounded, color: AppColors.gold500),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(color: AppColors.fg),
                decoration: const InputDecoration(
                  labelText: 'Notes / Remarks',
                  hintText: 'Client interested in on-grid subsidy model',
                  prefixIcon: Icon(Icons.notes_rounded, color: AppColors.gold500),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold500,
                    foregroundColor: AppColors.ink900,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.ink900,
                          ),
                        )
                      : const Text(
                          'Save & Add Lead',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),

                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
