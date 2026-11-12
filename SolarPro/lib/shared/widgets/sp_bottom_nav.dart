import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

class SpNavItem {
  final IconData icon;
  final String label;
  final IconData? activeIcon;
  const SpNavItem({required this.icon, required this.label, this.activeIcon});
}

/// White bottom bar with an amber pixel indicator that hops between tabs.
class SpBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final List<SpNavItem>? items;

  const SpBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
    this.items,
  });

  static const _defaultItems = [
    SpNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    SpNavItem(icon: Icons.people_outline_rounded, activeIcon: Icons.people_rounded, label: 'Leads'),
    SpNavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Customers'),
    SpNavItem(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2_rounded, label: 'Inventory'),
    SpNavItem(icon: Icons.more_horiz_rounded, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    final navItems = items ?? _defaultItems;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.navy800,
        border: Border(top: BorderSide(color: AppColors.navy500, width: 1.4)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / navItems.length;
              return Stack(
                children: [
                  // Hopping indicator: a short amber bar riding the top edge.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutBack,
                    left: selectedIndex * tabWidth + (tabWidth - 28) / 2,
                    top: 0,
                    child: Container(
                      width: 28,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.gold500,
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final (i, item) in navItems.indexed)
                        Expanded(
                          child: _NavButton(
                            item: item,
                            selected: selectedIndex == i,
                            onTap: () {
                              if (selectedIndex != i) HapticFeedback.selectionClick();
                              onTap(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final SpNavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.gold400 : AppColors.ink700;
    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: selected ? 1 : 0),
              duration: const Duration(milliseconds: 460),
              curve: Curves.elasticOut,
              builder: (context, v, child) => Transform.translate(
                offset: Offset(0, -3 * v),
                child: Transform.scale(scale: 1 + 0.14 * v, child: child),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  selected ? (item.activeIcon ?? item.icon) : item.icon,
                  key: ValueKey(selected),
                  size: 23,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: AppTextStyles.caption.copyWith(
                fontSize: 10.5,
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}
