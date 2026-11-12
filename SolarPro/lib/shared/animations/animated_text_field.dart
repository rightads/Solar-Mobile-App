import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

/// A rich, animated text input field with focus glow, icon bounce, and smooth validation.
/// Inspired by the Qubstudio and Cleveroad form field micro-interactions.
class AnimatedAuthField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;

  const AnimatedAuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.onChanged,
    this.focusNode,
    this.validator,
  });

  @override
  State<AnimatedAuthField> createState() => _AnimatedAuthFieldState();
}

class _AnimatedAuthFieldState extends State<AnimatedAuthField> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.removeListener(_onFocusChange);
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: AppTextStyles.labelMedium.copyWith(
            color: _isFocused ? AppColors.gold400 : AppColors.grey400,
            fontWeight: _isFocused ? FontWeight.w600 : FontWeight.w500,
            fontSize: 12.5,
          ),
          child: Text(widget.label),
        ),
        const SizedBox(height: 6),
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: AppColors.navy800.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isFocused
                  ? AppColors.gold500
                  : AppColors.navy600.withValues(alpha: 0.7),
              width: _isFocused ? 1.8 : 1.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.gold500.withValues(alpha: 0.22),
                      blurRadius: 16,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            keyboardType: widget.keyboardType,
            obscureText: widget.isPassword && _obscureText,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            style: const TextStyle(
              color: AppColors.fg,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: AppColors.gold500,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: const TextStyle(color: AppColors.grey500, fontSize: 14),
              prefixIcon: AnimatedScale(
                scale: _isFocused ? 1.12 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  widget.prefixIcon,
                  color: _isFocused ? AppColors.gold500 : AppColors.grey500,
                  size: 20,
                ),
              ),
              suffixIcon: widget.isPassword
                  ? IconButton(
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _obscureText
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          key: ValueKey(_obscureText),
                          color: _isFocused ? AppColors.gold400 : AppColors.grey500,
                          size: 20,
                        ),
                      ),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    )
                  : (widget.controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel, color: AppColors.grey600, size: 18),
                          onPressed: () {
                            widget.controller.clear();
                            if (widget.onChanged != null) widget.onChanged!('');
                          },
                        )
                      : null),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            ),
          ),
        ),
      ],
    );
  }
}
