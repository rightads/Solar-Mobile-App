import 'package:flutter/material.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/shared/widgets/sp_password_field.dart';

/// Bottom sheet that lets any signed-in user (admin, employee or client)
/// change their password. Accounts created without a password (OTP-only)
/// can set their first one.
Future<void> showChangePasswordSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navy800,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ChangePasswordSheet(),
  );
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _hasPassword = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ApiClient().getMe().then((me) {
      if (mounted && me != null && me['has_password'] == false) {
        setState(() => _hasPassword = false);
      }
    });
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text;
    final next = _newCtrl.text;
    String? problem;
    if (_hasPassword && current.isEmpty) {
      problem = 'Please enter your current password';
    } else {
      problem = passwordProblem(next);
    }
    if (problem == null && next != _confirmCtrl.text) problem = 'New passwords do not match';
    if (problem == null && _hasPassword && next == current) {
      problem = 'The new password must be different from your current password';
    }
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final message = await ApiClient().changePassword(
        currentPassword: _hasPassword ? current : null,
        newPassword: next,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success));
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
            Text(_hasPassword ? 'Change Password' : 'Set a Password', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Other devices signed in to this account will be logged out.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400),
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
            if (_hasPassword) ...[
              SpPasswordField(
                controller: _currentCtrl,
                hint: 'Current password',
                autofillHints: const [AutofillHints.password],
              ),
              const SizedBox(height: 12),
            ],
            SpPasswordField(
              controller: _newCtrl,
              hint: 'New password (8+ letters & numbers)',
              icon: Icons.lock_reset_rounded,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 12),
            SpPasswordField(
              controller: _confirmCtrl,
              hint: 'Confirm new password',
              icon: Icons.lock_reset_rounded,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold500,
                foregroundColor: AppColors.ink900,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink900),
                    )
                  : Text(_hasPassword ? 'Update Password' : 'Set Password',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
