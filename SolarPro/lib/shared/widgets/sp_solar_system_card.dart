import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/shared/animations/pixel_art.dart';

/// Client home hero: capacity, current stage, pixel house and a segmented
/// 10-stage progress bar that fills one block at a time.
class SpSolarSystemCard extends StatelessWidget {
  final double capacityKw;
  final String stageLabel;
  final int completed;
  final int total;
  final int percentage;
  final bool active;

  const SpSolarSystemCard({
    super.key,
    required this.capacityKw,
    required this.stageLabel,
    required this.completed,
    required this.total,
    required this.percentage,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final kw = capacityKw > 0
        ? (capacityKw == capacityKw.roundToDouble() ? capacityKw.toStringAsFixed(0) : capacityKw.toStringAsFixed(1))
        : '--';
    return Container(
      decoration: AppDecor.card(radius: AppRadius.xxl, shadowOffset: 4),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.white, AppColors.gold100.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            right: -6,
            bottom: 38,
            width: 190,
            height: 128,
            child: PixelScenes.house(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Your Solar System', style: AppTextStyles.headlineSmall.copyWith(fontSize: 15)),
                    const Spacer(),
                    _StatusPill(active: active),
                  ],
                ),
                const SizedBox(height: 14),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: capacityKw),
                  duration: const Duration(milliseconds: 1400),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        capacityKw > 0 ? v.toStringAsFixed(kw.contains('.') ? 1 : 0) : kw,
                        style: AppTextStyles.displayLarge.copyWith(fontSize: 44, height: 1),
                      ),
                      const SizedBox(width: 6),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('kW', style: AppTextStyles.displaySmall.copyWith(fontSize: 22)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('System capacity', style: AppTextStyles.bodySmall),
                const SizedBox(height: 14),
                SizedBox(
                  width: 170,
                  child: Text(
                    stageLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelLarge.copyWith(color: AppColors.ink700),
                  ),
                ),
                const SizedBox(height: 26),
                _SegmentedProgress(completed: completed, total: total),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      completed >= total ? 'All $total stages complete' : 'Stage ${math.min(completed + 1, total)} of $total',
                      style: AppTextStyles.caption.copyWith(color: AppColors.grey400),
                    ),
                    const Spacer(),
                    Text('$percentage%',
                        style: AppTextStyles.labelLarge.copyWith(color: AppColors.ink900, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatefulWidget {
  final bool active;
  const _StatusPill({required this.active});

  @override
  State<_StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<_StatusPill> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
            child: Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          ),
          const SizedBox(width: 6),
          Text(widget.active ? 'Active' : 'In review',
              style: AppTextStyles.caption.copyWith(color: AppColors.ink900, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SegmentedProgress extends StatelessWidget {
  final int completed;
  final int total;
  const _SegmentedProgress({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final n = total <= 0 ? 10 : total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: completed.toDouble()),
      duration: Duration(milliseconds: 300 + 120 * completed),
      curve: Curves.easeOut,
      builder: (context, v, _) => Row(
        children: List.generate(n, (i) {
          final fill = (v - i).clamp(0.0, 1.0);
          final current = i == completed && completed < n;
          return Expanded(
            child: Container(
              height: 14,
              margin: EdgeInsets.only(right: i == n - 1 ? 0 : 4),
              decoration: BoxDecoration(
                color: AppColors.navy700,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: current ? AppColors.gold400 : AppColors.navy500, width: current ? 1.6 : 1.1),
              ),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fill,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
