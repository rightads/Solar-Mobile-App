import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

// ─── Global page transition ──────────────────────────────────────────────────
/// Incoming page rises in with a fade + subtle scale; the outgoing page eases
/// back and dims. Registered app-wide through [ThemeData.pageTransitionsTheme],
/// so GoRouter pages and MaterialPageRoutes all share it.
class SpPageTransitionsBuilder extends PageTransitionsBuilder {
  const SpPageTransitionsBuilder();

  @override
  Duration get transitionDuration => AppMotion.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final enter = CurvedAnimation(
      parent: animation,
      curve: AppMotion.emphasized,
      reverseCurve: Curves.easeInCubic,
    );
    final exit = CurvedAnimation(
        parent: secondaryAnimation, curve: AppMotion.emphasized);

    return AnimatedBuilder(
      animation: Listenable.merge([enter, exit]),
      child: child,
      builder: (context, child) {
        final e = enter.value;
        final x = exit.value;
        return Opacity(
          opacity: e.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - e) * 36),
            child: Transform.scale(
              scale: (0.96 + 0.04 * e) * (1 - 0.04 * x),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  AppColors.navy900.withValues(alpha: 0.45 * x),
                  BlendMode.srcATop,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Pressable ───────────────────────────────────────────────────────────────
/// Scales its child down while pressed and springs back on release.
class SpPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool haptic;

  const SpPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.haptic = true,
  });

  @override
  State<SpPressable> createState() => _SpPressableState();
}

class _SpPressableState extends State<SpPressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        duration: _down ? AppMotion.fast : const Duration(milliseconds: 420),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}

// ─── Pixel button ────────────────────────────────────────────────────────────
/// Amber call-to-action with a hard bottom edge that "clicks" down on press,
/// matching the chunky pixel buttons in the design.
class SpPixelButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final IconData? trailingIcon;
  final Color color;
  final Color edgeColor;
  final Color foreground;
  final double height;
  final bool expand;

  const SpPixelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.trailingIcon,
    this.color = AppColors.gold500,
    this.edgeColor = AppColors.goldDeep,
    this.foreground = AppColors.ink900,
    this.height = 52,
    this.expand = true,
  });

  const SpPixelButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.trailingIcon,
    this.height = 52,
    this.expand = true,
  })  : color = AppColors.white,
        edgeColor = AppColors.navy500,
        foreground = AppColors.ink900;

  @override
  State<SpPixelButton> createState() => _SpPixelButtonState();
}

class _SpPixelButtonState extends State<SpPixelButton> {
  bool _down = false;
  static const double _edge = 4;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final depth = _down ? 1.0 : _edge;
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: widget.foreground),
          const SizedBox(width: 8),
        ],
        if (widget.label.isNotEmpty)
          Flexible(
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelLarge.copyWith(
                color: widget.foreground,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        if (widget.trailingIcon != null) ...[
          if (widget.label.isNotEmpty) const SizedBox(width: 8),
          Icon(widget.trailingIcon, size: 18, color: widget.foreground),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: () => setState(() => _down = false),
        onTap: _enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedOpacity(
          duration: AppMotion.fast,
          opacity: widget.onPressed == null ? 0.5 : 1,
          child: SizedBox(
            height: widget.height + _edge,
            child: Stack(
              children: [
                Positioned.fill(
                  top: _edge,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.edgeColor,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 90),
                  curve: Curves.easeOut,
                  left: 0,
                  right: 0,
                  top: _edge - depth,
                  height: widget.height,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: widget.edgeColor, width: 1.4),
                    ),
                    alignment: Alignment.center,
                    child: AnimatedSwitcher(
                      duration: AppMotion.medium,
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: ScaleTransition(scale: a, child: c),
                      ),
                      child: widget.isLoading
                          ? SizedBox(
                              key: const ValueKey('loading'),
                              height: 22,
                              child: SpPixelLoader(color: widget.foreground),
                            )
                          : KeyedSubtree(
                              key: const ValueKey('label'), child: content),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three bouncing pixel squares used as a loading indicator.
class SpPixelLoader extends StatefulWidget {
  final Color color;
  final double size;
  const SpPixelLoader(
      {super.key, this.color = AppColors.ink900, this.size = 7});

  @override
  State<SpPixelLoader> createState() => _SpPixelLoaderState();
}

class _SpPixelLoaderState extends State<SpPixelLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = ((_c.value - i * 0.15) % 1.0);
          final lift = t < 0.4
              ? Curves.easeOut.transform(t / 0.4)
              : 1 - Curves.easeIn.transform(((t - 0.4) / 0.6).clamp(0, 1));
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.size * 0.35),
            child: Transform.translate(
              offset: Offset(0, -lift * widget.size * 0.9),
              child: Container(
                  width: widget.size, height: widget.size, color: widget.color),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Pixel card ──────────────────────────────────────────────────────────────
/// White outlined card with a hard offset shadow; optional tap with press motion.
class SpCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;
  final Color borderColor;
  final double radius;

  const SpCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = AppColors.navy800,
    this.borderColor = AppColors.navy500,
    this.radius = AppRadius.xl,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration:
          AppDecor.card(color: color, border: borderColor, radius: radius),
      child: child,
    );
    if (onTap == null) return card;
    return SpPressable(onTap: onTap, pressedScale: 0.975, child: card);
  }
}

// ─── Entrance ────────────────────────────────────────────────────────────────
/// Fades + slides its child in once, staggered by [index].
class SpEntrance extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;
  final Duration step;
  final Offset from;

  const SpEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDelay = Duration.zero,
    this.step = const Duration(milliseconds: 60),
    this.from = const Offset(0, 24),
  });

  @override
  State<SpEntrance> createState() => _SpEntranceState();
}

class _SpEntranceState extends State<SpEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void initState() {
    super.initState();
    final delay = widget.baseDelay + widget.step * widget.index.clamp(0, 12);
    Future.delayed(delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = AppMotion.emphasized.transform(_c.value);
        return Opacity(
          opacity: t,
          child:
              Transform.translate(offset: widget.from * (1 - t), child: child),
        );
      },
    );
  }
}

/// Drop-in [IndexedStack] that fades + rises the newly selected tab in.
/// Tab state is preserved (children are never rebuilt from scratch).
class SpAnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  const SpAnimatedIndexedStack(
      {super.key, required this.index, required this.children});

  @override
  State<SpAnimatedIndexedStack> createState() => _SpAnimatedIndexedStackState();
}

class _SpAnimatedIndexedStackState extends State<SpAnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: AppMotion.slow, value: 1);

  @override
  void didUpdateWidget(covariant SpAnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) _c.forward(from: 0);
  }

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
        final t = AppMotion.emphasized.transform(_c.value);
        return Opacity(
          opacity: (0.2 + 0.8 * t).clamp(0.0, 1.0),
          child: Transform.translate(
              offset: Offset(0, 18 * (1 - t)), child: child),
        );
      },
      child: IndexedStack(index: widget.index, children: widget.children),
    );
  }
}
