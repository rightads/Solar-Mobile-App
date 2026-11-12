import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A fluid, morphing, GPU-accelerated liquid background with solar flare orbs & particle waves.
/// Inspired by the Cleveroad and Qubstudio Dribbble design aesthetics.
class SolarLiquidBackground extends StatefulWidget {
  final Widget child;
  final int portalIndex; // 0: Client (Amber/Gold), 1: Employee (Electric Cyan/Blue), 2: Admin (Deep Violet/Teal)

  const SolarLiquidBackground({
    super.key,
    required this.child,
    this.portalIndex = 0,
  });

  @override
  State<SolarLiquidBackground> createState() => _SolarLiquidBackgroundState();
}

class _SolarLiquidBackgroundState extends State<SolarLiquidBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return CustomPaint(
          painter: _LiquidBackgroundPainter(
            progress: _animController.value,
            portalIndex: widget.portalIndex,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _LiquidBackgroundPainter extends CustomPainter {
  final double progress;
  final int portalIndex;

  _LiquidBackgroundPainter({
    required this.progress,
    required this.portalIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;

    // Base background fill (Deep Midnight Navy)
    final bgPaint = Paint()..color = const Color(0xFF090D1A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Dynamic Orb Palette based on active Portal
    final List<Color> orbColors;
    if (portalIndex == 0) {
      // Client Portal: Warm Sunburst, Golden Solar Amber, Coral Flare
      orbColors = [
        const Color(0xFFF59E0B), // Amber 500
        const Color(0xFFFF6B00), // Sun Orange
        const Color(0xFFFFD166), // Warm Sun Glow
        const Color(0xFFE11D48), // Rose Coral
      ];
    } else if (portalIndex == 1) {
      // Employee Portal: Electric Cyan, High-Voltage Blue, Emerald Grid
      orbColors = [
        const Color(0xFF00F0FF), // Cyber Cyan
        const Color(0xFF3B82F6), // Blue 500
        const Color(0xFF10B981), // Emerald 500
        const Color(0xFF6366F1), // Indigo 500
      ];
    } else {
      // Admin Portal: Majestic Royal Purple, Deep Teal, Neon Fuchsia
      orbColors = [
        const Color(0xFF8B5CF6), // Violet 500
        const Color(0xFF14B8A6), // Teal 500
        const Color(0xFFEC4899), // Pink 500
        const Color(0xFF06B6D4), // Cyan 500
      ];
    }

    // ── Floating Fluid Glow Orbs ─────────────────────────────────────────────

    // Orb 1: Top Right Morphing Sunburst
    final orb1Center = Offset(
      size.width * 0.85 + math.sin(t) * 35,
      size.height * 0.15 + math.cos(t * 1.2) * 30,
    );
    final orb1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          orbColors[0].withValues(alpha: 0.28),
          orbColors[1].withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: orb1Center, radius: 240));
    canvas.drawCircle(orb1Center, 240, orb1Paint);

    // Orb 2: Bottom Left Ambient Pool
    final orb2Center = Offset(
      size.width * 0.12 + math.cos(t * 0.8) * 40,
      size.height * 0.82 + math.sin(t * 1.1) * 35,
    );
    final orb2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          orbColors[1].withValues(alpha: 0.22),
          orbColors[2].withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: orb2Center, radius: 260));
    canvas.drawCircle(orb2Center, 260, orb2Paint);

    // Orb 3: Center Mid Floating Accent
    final orb3Center = Offset(
      size.width * 0.5 + math.sin(t * 1.4) * 50,
      size.height * 0.45 + math.cos(t * 0.9) * 45,
    );
    final orb3Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          orbColors[3].withValues(alpha: 0.16),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: orb3Center, radius: 180));
    canvas.drawCircle(orb3Center, 180, orb3Paint);

    // ── Organic Liquid Wave Curves (Cleveroad Style) ─────────────────────────
    final wavePath = Path();
    wavePath.moveTo(0, size.height * 0.35 + math.sin(t) * 20);
    wavePath.cubicTo(
      size.width * 0.25,
      size.height * 0.28 + math.cos(t * 1.3) * 25,
      size.width * 0.65,
      size.height * 0.42 + math.sin(t * 0.9) * 30,
      size.width,
      size.height * 0.30 + math.cos(t) * 20,
    );
    wavePath.lineTo(size.width, 0);
    wavePath.lineTo(0, 0);
    wavePath.close();

    final wavePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          orbColors[0].withValues(alpha: 0.04),
          orbColors[1].withValues(alpha: 0.02),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5));
    canvas.drawPath(wavePath, wavePaint);

    // ── Shimmering Solar Micro-Particles ────────────────────────────────────
    final random = math.Random(42);
    final particlePaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 24; i++) {
      final seedX = random.nextDouble();
      final seedY = random.nextDouble();
      final seedSpeed = 0.5 + random.nextDouble() * 1.5;
      final seedRadius = 1.2 + random.nextDouble() * 2.2;

      // Particle drifts upward seamlessly
      final py = (seedY * size.height - (progress * size.height * seedSpeed)) % size.height;
      final px = (seedX * size.width + math.sin(t + i) * 16) % size.width;
      final alpha = (0.2 + math.sin(t * 2 + i) * 0.15).clamp(0.05, 0.45);

      particlePaint.color = (i % 2 == 0 ? orbColors[0] : Colors.white).withValues(alpha: alpha);
      canvas.drawCircle(Offset(px, py), seedRadius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LiquidBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.portalIndex != portalIndex;
  }
}
