import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/shared/animations/animated_counter.dart';

class SpStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final String change;
  final int delay;

  const SpStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.change,
    this.delay = 0,
  });

  Widget _buildAnimatedValue() {
    // Check if value can be parsed as a dynamic number with prefix/suffix (e.g. ₹12,450, 4.8 kW, 98%)
    final clean = value.replaceAll(',', '');
    final match = RegExp(r'^([^0-9\.]*)([0-9]+(?:\.[0-9]+)?)(.*)$').firstMatch(clean);

    if (match != null) {
      final prefix = match.group(1) ?? '';
      final numStr = match.group(2) ?? '';
      final suffix = match.group(3) ?? '';
      final numVal = num.tryParse(numStr);

      if (numVal != null) {
        final hasDecimal = numStr.contains('.');
        return AnimatedCounter(
          value: numVal,
          prefix: prefix,
          suffix: suffix,
          fractionDigits: hasDecimal ? 1 : 0,
          duration: Duration(milliseconds: 1200 + delay),
          style: AppTextStyles.headlineLarge.copyWith(fontSize: 22, height: 1.1),
        );
      }
    }

    return Text(
      value,
      style: AppTextStyles.headlineLarge.copyWith(fontSize: 22, height: 1.1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppDecor.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: iconColor.withValues(alpha: 0.45)),
                ),
                child: Icon(icon, size: 17, color: AppColors.ink900),
              ).animate().scale(delay: Duration(milliseconds: delay + 100), duration: 300.ms, curve: Curves.easeOutBack),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  change,
                  style: AppTextStyles.caption.copyWith(
                    color: iconColor,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _buildAnimatedValue(),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 450.ms)
        .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
  }
}
