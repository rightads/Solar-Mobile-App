import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_pro/core/constants/app_constants.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/services/session_store.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/shared/widgets/sp_password_field.dart';

/// Opened from the password reset email (solarpro://app/reset-password?token=…).
/// Lets the user choose a new password, then sends them to sign in.
class ResetPasswordScreen extends StatefulWidget {
  final String token;
  const ResetPasswordScreen({super.key, required this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _hasToken => widget.token.trim().length >= 20;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final next = _newCtrl.text;
    String? problem = passwordProblem(next);
    if (problem == null && next != _confirmCtrl.text) problem = 'Passwords do not match';
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final message = await ApiClient().resetPassword(token: widget.token, newPassword: next);
      // Every session on every device was signed out by the reset.
      await SessionStore.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.success),
      );
      context.go(AppRoutes.login);
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
    return Scaffold(
      backgroundColor: AppColors.navy900,
      appBar: AppBar(
        title: const Text('Reset Password', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          tooltip: 'Back to sign in',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.login),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const Icon(Icons.lock_reset_rounded, size: 56, color: AppColors.gold500),
                const SizedBox(height: 16),
                Text(
                  _hasToken ? 'Choose a new password' : 'This reset link is incomplete',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _hasToken
                      ? 'You\'ll be signed out on every device and can then sign in with the new password.'
                      : 'Open the link from your email again, or use "Forgot password?" on the sign-in screen '
                          'to get a new one.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400),
                ),
                const SizedBox(height: 24),
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
                if (_hasToken) ...[
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
                ],
                ElevatedButton(
                  onPressed: _saving ? null : (_hasToken ? _submit : () => context.go(AppRoutes.login)),
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
                      : Text(_hasToken ? 'Save New Password' : 'Go to Sign In',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
