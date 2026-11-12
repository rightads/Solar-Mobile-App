import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';
import 'package:solar_pro/shared/animations/motion.dart';

/// "Hi, Name 👋 / Role" top bar used by every portal home.
class SpGreetingHeader extends StatelessWidget implements PreferredSizeWidget {
  final String name;
  final String role;
  final String? badge;
  final VoidCallback? onBell;
  final VoidCallback? onLogout;
  final int unread;

  const SpGreetingHeader({
    super.key,
    required this.name,
    required this.role,
    this.badge,
    this.onBell,
    this.onLogout,
    this.unread = 0,
  });

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    final first = name.trim().isEmpty ? 'there' : name.trim().split(' ').first;
    final initial = first == 'there' ? '?' : first[0].toUpperCase();
    return Container(
      color: AppColors.navy900,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 8),
          child: Row(
            children: [
              SpEntrance(
                from: const Offset(-16, 0),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.gold100,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.ink900, width: 1.6),
                    boxShadow: [BoxShadow(color: AppColors.navy500.withValues(alpha: 0.6), offset: const Offset(0, 3))],
                  ),
                  alignment: Alignment.center,
                  child: Text(initial, style: AppTextStyles.displaySmall.copyWith(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SpEntrance(
                  index: 1,
                  from: const Offset(-12, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Hi, $first',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.headlineMedium.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const _Wave(),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Flexible(
                            child: Text(role,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.grey400)),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.gold100,
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                                border: Border.all(color: AppColors.gold300),
                              ),
                              child: Text(badge!,
                                  style: AppTextStyles.caption.copyWith(color: AppColors.ink900, fontWeight: FontWeight.w800, fontSize: 10)),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (onBell != null) _HeaderButton(icon: Icons.notifications_none_rounded, onTap: onBell!, dot: unread > 0, ring: true),
              if (onLogout != null) ...[
                const SizedBox(width: 8),
                _HeaderButton(icon: Icons.logout_rounded, onTap: onLogout!, color: AppColors.error),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool dot;
  final bool ring;
  final Color color;
  const _HeaderButton({required this.icon, required this.onTap, this.dot = false, this.ring = false, this.color = AppColors.ink900});

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void initState() {
    super.initState();
    if (widget.ring) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SpPressable(
      onTap: widget.onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: AppDecor.card(radius: AppRadius.md, shadowOffset: 2),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) {
                // A short bell "ring" at the start of every loop.
                final t = _c.value;
                final a = t < 0.2 ? math.sin(t / 0.2 * math.pi * 5) * 0.3 * (1 - t / 0.2) : 0.0;
                return Transform.rotate(angle: a, alignment: Alignment.topCenter, child: child);
              },
              child: Icon(widget.icon, size: 21, color: widget.color),
            ),
            if (widget.dot)
              Positioned(
                top: 9,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.gold500,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 1.4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Wave extends StatefulWidget {
  const _Wave();
  @override
  State<_Wave> createState() => _WaveState();
}

class _WaveState extends State<_Wave> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final a = t < 0.4 ? math.sin(t / 0.4 * math.pi * 4) * 0.4 : 0.0;
        return Transform.rotate(angle: a, alignment: Alignment.bottomRight, child: child);
      },
      child: const Text('👋', style: TextStyle(fontSize: 17)),
    );
  }
}
