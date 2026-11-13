import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_pro/core/network/api_client.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/shared/widgets/sp_password_field.dart';

/// "Forgot password?" sheet on the login screen.
///
/// Step 1 emails a reset link (opens the app on the phone) plus a 6-digit
/// code. Step 2 lets the user type that code here instead, which is how it
/// works on Windows/desktop or when the link does not open the app.
/// [onUseOtp] adds the "sign in with SMS OTP instead" alternative.
///
/// Returns the email address when the password was reset, otherwise null.
Future<String?> showForgotPasswordSheet(
  BuildContext context, {
  String initialEmail = '',
  VoidCallback? onUseOtp,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.navy800,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ForgotPasswordSheet(initialEmail: initialEmail, onUseOtp: onUseOtp),
  );
}

class _ForgotPasswordSheet extends StatefulWidget {
  final String initialEmail;
  final VoidCallback? onUseOtp;
  const _ForgotPasswordSheet({required this.initialEmail, this.onUseOtp});

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  late final _emailCtrl = TextEditingController(text: widget.initialEmail.contains('@') ? widget.initialEmail.trim() : '');
  final _codeCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  /// false = ask for the email, true = enter code + new password.
  bool _codeStep = false;
  bool _busy = false;
  String? _error;
  String? _info;
  int _resendIn = 0;
  Timer? _timer;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _timer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _resendIn = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  String _clean(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _sendLink() async {
    final email = _emailCtrl.text.trim();
    if (!_emailRe.hasMatch(email)) {
      setState(() => _error = 'Please enter the email address of your account');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiClient().forgotPassword(email);
      if (!mounted) return;
      _startCooldown();
      setState(() {
        _busy = false;
        _codeStep = true;
        _info = 'If $email has a SolarPro account, we\'ve sent it a reset link and a 6-digit code. '
            'Tap the link on this phone, or enter the code below.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _clean(e);
        });
      }
    }
  }

  Future<void> _reset() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final next = _newCtrl.text;
    String? problem;
    if (!_emailRe.hasMatch(email)) {
      problem = 'Please enter the email address of your account';
    } else if (code.length != 6) {
      problem = 'Enter the 6-digit code from the email';
    } else {
      problem = passwordProblem(next);
    }
    if (problem == null && next != _confirmCtrl.text) problem = 'Passwords do not match';
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await ApiClient().resetPassword(email: email, code: code, newPassword: next);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(email);
      messenger.showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _clean(e);
        });
      }
    }
  }

  InputDecoration _decor(String hint, IconData icon) =>
      InputDecoration(hintText: hint, prefixIcon: Icon(icon), counterText: '');

  Widget _banner(String text, Color color) => Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: color)),
      );

  Widget _primaryButton(String label, VoidCallback onPressed) => ElevatedButton(
        onPressed: _busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold500,
          foregroundColor: AppColors.ink900,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink900),
              )
            : Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      );

  Widget _link(String label, VoidCallback? onPressed) => TextButton(
        onPressed: onPressed,
        child: Text(
          label,
          style: AppTextStyles.labelMedium.copyWith(
            color: onPressed == null ? AppColors.grey400 : AppColors.ink900,
            decoration: onPressed == null ? null : TextDecoration.underline,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final emailField = TextField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      textInputAction: _codeStep ? TextInputAction.next : TextInputAction.done,
      onSubmitted: _codeStep ? null : (_) => _sendLink(),
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
      decoration: _decor('Email address', Icons.mail_outline_rounded),
    );

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
            Text(_codeStep ? 'Enter Reset Code' : 'Forgot Password?', style: AppTextStyles.headlineSmall),
            const SizedBox(height: 4),
            Text(
              _codeStep
                  ? 'Use the 6-digit code from the reset email to choose a new password.'
                  : 'We\'ll email you a link to reset your password, plus a 6-digit code you can type in here.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400),
            ),
            const SizedBox(height: 16),
            if (_info != null && _codeStep) _banner(_info!, AppColors.success),
            if (_error != null) _banner(_error!, AppColors.error),
            if (!_codeStep) ...[
              emailField,
              const SizedBox(height: 20),
              _primaryButton('Email Me a Reset Link', _sendLink),
              const SizedBox(height: 8),
              _link('I already have a code', () => setState(() {
                    _codeStep = true;
                    _error = null;
                  })),
              if (widget.onUseOtp != null)
                _link('Sign in with SMS OTP instead', () {
                  Navigator.of(context).pop();
                  widget.onUseOtp!();
                }),
            ] else ...[
              emailField,
              const SizedBox(height: 12),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofillHints: const [AutofillHints.oneTimeCode],
                textInputAction: TextInputAction.next,
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg, letterSpacing: 4),
                decoration: _decor('6-digit code', Icons.pin_outlined),
              ),
              const SizedBox(height: 12),
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
                onSubmitted: (_) => _reset(),
              ),
              const SizedBox(height: 20),
              _primaryButton('Reset Password', _reset),
              const SizedBox(height: 8),
              _link(
                _resendIn > 0 ? 'Resend email in ${_resendIn}s' : 'Resend reset email',
                _resendIn > 0 || _busy ? null : _sendLink,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
