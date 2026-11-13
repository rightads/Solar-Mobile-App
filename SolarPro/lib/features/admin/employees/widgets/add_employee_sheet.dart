import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_pro/core/constants/staff_departments.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/shared/widgets/sp_password_field.dart';

/// Admin form to create a staff login (employee ID) in one of the four
/// departments. Returns true when an employee was created.
class AddEmployeeSheet extends StatefulWidget {
  final String initialDepartment;
  const AddEmployeeSheet({super.key, this.initialDepartment = 'sales'});

  static Future<bool> show(BuildContext context, {String? department}) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.navy800,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddEmployeeSheet(initialDepartment: departmentOf(department) ?? 'sales'),
    );
    return created == true;
  }

  @override
  State<AddEmployeeSheet> createState() => _AddEmployeeSheetState();
}

class _AddEmployeeSheetState extends State<AddEmployeeSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  late String _department = widget.initialDepartment;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_nameCtrl, _phoneCtrl, _emailCtrl, _passwordCtrl, _confirmCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    String? problem;
    if (name.length < 2) {
      problem = 'Please enter the employee name';
    } else if (phone.length != 10) {
      problem = 'Please enter a valid 10-digit mobile number';
    } else if (email.isNotEmpty && !email.contains('@')) {
      problem = 'Please enter a valid email address (or leave it empty)';
    } else {
      problem = passwordProblem(password);
    }
    if (problem == null && password != _confirmCtrl.text) problem = 'Passwords do not match';
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final emp = await ApiClient().createEmployee(
        name: name,
        phone: phone,
        email: email,
        department: _department,
        password: password,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      final empNo = emp?['employee_no']?.toString() ?? '';
      messenger.showSnackBar(SnackBar(
        content: Text('$name added${empNo.isEmpty ? '' : ' ($empNo)'}. They can sign in with their mobile and this password.'),
        backgroundColor: AppColors.success,
      ));
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppColors.grey600, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Add Employee', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 4),
            Text('Creates a login the employee can use right away.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400)),
            const SizedBox(height: 16),
            Text('Department', style: AppTextStyles.labelMedium.copyWith(color: AppColors.grey400)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in kStaffDepartments)
                  ChoiceChip(
                    avatar: Icon(d.icon, size: 16, color: _department == d.key ? AppColors.ink900 : d.color),
                    label: Text(d.label),
                    selected: _department == d.key,
                    selectedColor: d.color.withValues(alpha: 0.25),
                    onSelected: (_) => setState(() => _department = d.key),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Full name', prefixIcon: Icon(Icons.badge_outlined)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Mobile number (10 digits)',
                prefixIcon: Icon(Icons.phone_outlined),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Email (optional)', prefixIcon: Icon(Icons.mail_outline_rounded)),
            ),
            const SizedBox(height: 12),
            SpPasswordField(controller: _passwordCtrl, hint: 'Password (8+ letters & numbers)'),
            const SizedBox(height: 12),
            SpPasswordField(
              controller: _confirmCtrl,
              hint: 'Confirm password',
              icon: Icons.lock_reset_rounded,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold500,
                foregroundColor: AppColors.ink900,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink900),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Create Employee', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
