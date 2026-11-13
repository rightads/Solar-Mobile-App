import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

/// Password input with a show / hide (eye) toggle.
class SpPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  const SpPasswordField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon = Icons.lock_outline_rounded,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints,
  });

  @override
  State<SpPasswordField> createState() => _SpPasswordFieldState();
}

class _SpPasswordFieldState extends State<SpPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      enableSuggestions: false,
      autocorrect: false,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.fg),
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: Icon(widget.icon),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(
            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.grey400,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

/// Same rule the server enforces: 8+ characters with letters and numbers.
String? passwordProblem(String password) {
  if (password.length < 8 || !RegExp(r'[A-Za-z]').hasMatch(password) || !RegExp(r'\d').hasMatch(password)) {
    return 'Password must be at least 8 characters with letters and numbers';
  }
  return null;
}
