import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

/// An energetic, liquid-sheen action button with tap-scale physics and morphing loader.
/// Inspired by the Cleveroad Dribbble micro-interaction.
class AnimatedAuthButton extends StatefulWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Gradient? gradient;
  final Color? glowColor;
  final double height;
  final double borderRadius;

  const AnimatedAuthButton({
    super.key,
    required this.text,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.gradient,
    this.glowColor,
    this.height = 54,
    this.borderRadius = 16,
  });

  @override
  State<AnimatedAuthButton> createState() => _AnimatedAuthButtonState();
}

class _AnimatedAuthButtonState extends State<AnimatedAuthButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = widget.gradient ??
        const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFFF6B00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

    final effectiveGlow = widget.glowColor ?? const Color(0xFFF59E0B);

    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        onTapDown: (_) {
          if (!widget.isLoading && widget.onPressed != null) {
            setState(() => _isPressed = true);
            HapticFeedback.lightImpact();
          }
        },
        onTapUp: (_) {
          if (!widget.isLoading && widget.onPressed != null) {
            setState(() => _isPressed = false);
            widget.onPressed!();
          }
        },
        onTapCancel: () {
          if (_isPressed) setState(() => _isPressed = false);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: effectiveGradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: effectiveGlow.withValues(alpha: widget.isLoading ? 0.2 : 0.42),
                blurRadius: widget.isLoading ? 12 : 22,
                offset: const Offset(0, 6),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Continuous Shimmer Light Ray Sweep
              if (!widget.isLoading)
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(widget.borderRadius),
                        child: FractionalTranslation(
                          translation: Offset(_shimmerController.value * 2.5 - 1.0, 0),
                          child: Transform.rotate(
                            angle: 0.35,
                            child: Container(
                              width: 60,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    AppColors.fg.withValues(alpha: 0.28),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

              // Content: Spinner when loading, Icon + Text when ready
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: widget.isLoading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.fg),
                        ),
                      )
                    : Row(
                        key: const ValueKey('ready'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(widget.icon, color: AppColors.fg, size: 20),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.text,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.fg,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
