import 'dart:math' as math;
import 'package:flutter/material.dart';

enum SunnyState {
  peekingLeft,
  wavingRight,
  curiousLooking,
  coveringEyes,
  celebrating,
  adminShield,
}

/// A high-end vector-illustrated animated character inspired by Olena Kychun (Qubstudio) on Dribbble.
/// Runs at 60fps with pure Flutter CustomPainter vector graphics, zero raster assets needed.
class SunnyMascot extends StatefulWidget {
  final SunnyState state;
  final double width;
  final double height;
  final double lookProgress; // -1.0 (left) to 1.0 (right)
  final VoidCallback? onTap;

  const SunnyMascot({
    super.key,
    required this.state,
    this.width = 220,
    this.height = 200,
    this.lookProgress = 0.0,
    this.onTap,
  });

  @override
  State<SunnyMascot> createState() => _SunnyMascotState();
}

class _SunnyMascotState extends State<SunnyMascot>
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _waveController;
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat();
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _waveController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _breathingController,
          _waveController,
          _blinkController,
        ]),
        builder: (context, child) {
          final breathY = math.sin(_breathingController.value * math.pi) * 5.0;
          final waveAngle = (math.sin(_waveController.value * math.pi * 2) * 0.35);
          final blinkVal = _blinkController.value;
          final isBlinking = blinkVal > 0.95 && blinkVal < 0.985;

          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: CustomPaint(
              painter: _SunnyMascotPainter(
                state: widget.state,
                breathY: breathY,
                waveAngle: waveAngle,
                isBlinking: isBlinking,
                lookProgress: widget.lookProgress,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SunnyMascotPainter extends CustomPainter {
  final SunnyState state;
  final double breathY;
  final double waveAngle;
  final bool isBlinking;
  final double lookProgress;

  _SunnyMascotPainter({
    required this.state,
    required this.breathY,
    required this.waveAngle,
    required this.isBlinking,
    required this.lookProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + breathY;
    final r = size.width * 0.36;

    // 1. Ambient Glow Halo
    final haloPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (state == SunnyState.adminShield ? const Color(0xFF00F0FF) : const Color(0xFFF59E0B))
              .withValues(alpha: 0.25),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 1.6));
    canvas.drawCircle(Offset(cx, cy), r * 1.6, haloPaint);

    // 2. Torso / Shirt (Modern Solar Polo)
    final shirtGradient = LinearGradient(
      colors: state == SunnyState.adminShield
          ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
          : state == SunnyState.wavingRight
              ? [const Color(0xFF10B981), const Color(0xFF059669)]
              : [const Color(0xFFF59E0B), const Color(0xFFD97706)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ).createShader(Rect.fromLTWH(cx - r * 0.9, cy + r * 0.4, r * 1.8, r * 0.8));

    final shirtPaint = Paint()..shader = shirtGradient;

    final torsoPath = Path()
      ..moveTo(cx - r * 0.85, size.height)
      ..quadraticBezierTo(cx - r * 0.7, cy + r * 0.42, cx - r * 0.35, cy + r * 0.42)
      ..lineTo(cx + r * 0.35, cy + r * 0.42)
      ..quadraticBezierTo(cx + r * 0.7, cy + r * 0.42, cx + r * 0.85, size.height)
      ..close();
    canvas.drawPath(torsoPath, shirtPaint);

    // Polo Collar
    final collarPaint = Paint()..color = const Color(0xFF0F172A);
    final collarPath = Path()
      ..moveTo(cx - r * 0.28, cy + r * 0.42)
      ..lineTo(cx, cy + r * 0.68)
      ..lineTo(cx + r * 0.28, cy + r * 0.42)
      ..close();
    canvas.drawPath(collarPath, collarPaint);

    // Solar Brand Crest Badge on chest
    final crestPaint = Paint()..color = const Color(0xFFFFD166);
    canvas.drawCircle(Offset(cx + r * 0.38, cy + r * 0.65), r * 0.08, crestPaint);
    final crestCenter = Paint()..color = const Color(0xFF0F172A);
    canvas.drawCircle(Offset(cx + r * 0.38, cy + r * 0.65), r * 0.04, crestCenter);

    // 3. Neck
    final skinShadow = Paint()..color = const Color(0xFFF5BA93);
    final neckRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + r * 0.35), width: r * 0.45, height: r * 0.36),
      const Radius.circular(8),
    );
    canvas.drawRRect(neckRect, skinShadow);

    // 4. Head & Face (Clean Dribbble Aesthetic)
    final skinPaint = Paint()..color = const Color(0xFFFFD7BE);
    final headRect = Rect.fromCenter(
      center: Offset(cx, cy - r * 0.05),
      width: r * 1.15,
      height: r * 1.25,
    );
    canvas.drawOval(headRect, skinPaint);

    // Rosy Cheeks
    final cheekPaint = Paint()
      ..color = const Color(0xFFFF7A85).withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(cx - r * 0.38, cy + r * 0.16), r * 0.14, cheekPaint);
    canvas.drawCircle(Offset(cx + r * 0.38, cy + r * 0.16), r * 0.14, cheekPaint);

    // Ears
    canvas.drawCircle(Offset(cx - r * 0.58, cy - r * 0.05), r * 0.16, skinPaint);
    canvas.drawCircle(Offset(cx + r * 0.58, cy - r * 0.05), r * 0.16, skinPaint);
    final innerEarPaint = Paint()..color = const Color(0xFFF5BA93);
    canvas.drawCircle(Offset(cx - r * 0.58, cy - r * 0.05), r * 0.09, innerEarPaint);
    canvas.drawCircle(Offset(cx + r * 0.58, cy - r * 0.05), r * 0.09, innerEarPaint);

    // 5. Stylish Dribbble Textured Hair (Olena Kychun style)
    final hairPaint = Paint()..color = const Color(0xFF3B2219);
    final hairHighlight = Paint()..color = const Color(0xFF5D382B);

    final hairPath = Path()
      ..moveTo(cx - r * 0.62, cy - r * 0.18)
      ..cubicTo(cx - r * 0.75, cy - r * 0.75, cx - r * 0.2, cy - r * 0.95, cx, cy - r * 0.85)
      ..cubicTo(cx + r * 0.35, cy - r * 0.98, cx + r * 0.75, cy - r * 0.65, cx + r * 0.62, cy - r * 0.18)
      ..cubicTo(cx + r * 0.55, cy - r * 0.42, cx + r * 0.2, cy - r * 0.55, cx + r * 0.05, cy - r * 0.48)
      ..cubicTo(cx - r * 0.15, cy - r * 0.55, cx - r * 0.45, cy - r * 0.45, cx - r * 0.62, cy - r * 0.18)
      ..close();
    canvas.drawPath(hairPath, hairPaint);

    // Front Hair Swoop Curl
    final curlPath = Path()
      ..moveTo(cx - r * 0.25, cy - r * 0.52)
      ..quadraticBezierTo(cx - r * 0.1, cy - r * 0.38, cx + r * 0.05, cy - r * 0.48)
      ..quadraticBezierTo(cx - r * 0.05, cy - r * 0.62, cx - r * 0.25, cy - r * 0.52)
      ..close();
    canvas.drawPath(curlPath, hairHighlight);

    // 6. Facial Expressions & Eyes
    if (state == SunnyState.coveringEyes) {
      _drawCoveringHands(canvas, cx, cy, r);
    } else {
      _drawEyes(canvas, cx, cy, r, isBlinking);
      _drawSmile(canvas, cx, cy, r);
    }

    // 7. Dynamic Hand / Arm Gestures
    if (state == SunnyState.wavingRight) {
      _drawWavingArm(canvas, cx + r * 0.65, cy + r * 0.1, r, waveAngle);
    } else if (state == SunnyState.peekingLeft) {
      _drawPeekingHands(canvas, cx - r * 0.85, cy + r * 0.3, r);
    } else if (state == SunnyState.celebrating) {
      _drawCelebratingArms(canvas, cx, cy, r, waveAngle);
    }

    // 8. Admin Cyber Visor
    if (state == SunnyState.adminShield) {
      _drawAdminVisor(canvas, cx, cy, r);
    }
  }

  void _drawEyes(Canvas canvas, double cx, double cy, double r, bool blink) {
    final browPaint = Paint()
      ..color = const Color(0xFF3B2219)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Dynamic Look Offset
    final lookX = lookProgress * (r * 0.08);

    // Eyebrows
    final leftBrow = Path()
      ..moveTo(cx - r * 0.35, cy - r * 0.18)
      ..quadraticBezierTo(cx - r * 0.24, cy - r * 0.25, cx - r * 0.12, cy - r * 0.18);
    final rightBrow = Path()
      ..moveTo(cx + r * 0.12, cy - r * 0.18)
      ..quadraticBezierTo(cx + r * 0.24, cy - r * 0.25, cx + r * 0.35, cy - r * 0.18);
    canvas.drawPath(leftBrow, browPaint);
    canvas.drawPath(rightBrow, browPaint);

    if (blink) {
      final lineEye = Paint()
        ..color = const Color(0xFF1E293B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx - r * 0.32, cy - r * 0.02), Offset(cx - r * 0.16, cy - r * 0.02), lineEye);
      canvas.drawLine(Offset(cx + r * 0.16, cy - r * 0.02), Offset(cx + r * 0.32, cy - r * 0.02), lineEye);
    } else {
      // Big, Glossy Anime-style Eyes
      final eyeWhite = Paint()..color = Colors.white;
      final pupil = Paint()..color = const Color(0xFF0F172A);
      final shine = Paint()..color = Colors.white;

      // Left Eye
      final leftCenter = Offset(cx - r * 0.24, cy - r * 0.02);
      canvas.drawOval(Rect.fromCenter(center: leftCenter, width: r * 0.24, height: r * 0.30), eyeWhite);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(leftCenter.dx + lookX, leftCenter.dy), width: r * 0.16, height: r * 0.22),
        pupil,
      );
      canvas.drawCircle(Offset(leftCenter.dx + lookX - 2, leftCenter.dy - 3), r * 0.045, shine);
      canvas.drawCircle(Offset(leftCenter.dx + lookX + 3, leftCenter.dy + 3), r * 0.022, shine);

      // Right Eye
      final rightCenter = Offset(cx + r * 0.24, cy - r * 0.02);
      canvas.drawOval(Rect.fromCenter(center: rightCenter, width: r * 0.24, height: r * 0.30), eyeWhite);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(rightCenter.dx + lookX, rightCenter.dy), width: r * 0.16, height: r * 0.22),
        pupil,
      );
      canvas.drawCircle(Offset(rightCenter.dx + lookX - 2, rightCenter.dy - 3), r * 0.045, shine);
      canvas.drawCircle(Offset(rightCenter.dx + lookX + 3, rightCenter.dy + 3), r * 0.022, shine);
    }
  }

  void _drawSmile(Canvas canvas, double cx, double cy, double r) {
    final mouthStroke = Paint()
      ..color = const Color(0xFF991B1B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final mouthFill = Paint()..color = const Color(0xFFDC2626);

    if (state == SunnyState.celebrating) {
      final happyMouth = Path()
        ..moveTo(cx - r * 0.22, cy + r * 0.18)
        ..quadraticBezierTo(cx, cy + r * 0.42, cx + r * 0.22, cy + r * 0.18)
        ..close();
      canvas.drawPath(happyMouth, mouthFill);
      canvas.drawPath(happyMouth, mouthStroke);

      final teeth = Paint()..color = Colors.white;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - r * 0.12, cy + r * 0.19, r * 0.24, r * 0.06), const Radius.circular(2)),
        teeth,
      );
    } else {
      final smile = Path()
        ..moveTo(cx - r * 0.16, cy + r * 0.20)
        ..quadraticBezierTo(cx, cy + r * 0.30, cx + r * 0.16, cy + r * 0.20);
      canvas.drawPath(smile, mouthStroke);
    }
  }

  void _drawCoveringHands(Canvas canvas, double cx, double cy, double r) {
    // Peek-a-boo: Hands covering eyes, peeking playfully between fingers!
    final handPaint = Paint()..color = const Color(0xFFFFD7BE);
    final handShadow = Paint()
      ..color = const Color(0xFFF5BA93)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Small peeking eyes between fingers
    final pupil = Paint()..color = const Color(0xFF0F172A);
    canvas.drawCircle(Offset(cx - r * 0.22, cy - r * 0.06), r * 0.05, pupil);
    canvas.drawCircle(Offset(cx + r * 0.22, cy - r * 0.06), r * 0.05, pupil);

    // Left Hand
    final leftHand = Path()
      ..moveTo(cx - r * 0.52, cy + r * 0.2)
      ..quadraticBezierTo(cx - r * 0.32, cy - r * 0.2, cx - r * 0.10, cy - r * 0.02)
      ..quadraticBezierTo(cx - r * 0.15, cy + r * 0.22, cx - r * 0.45, cy + r * 0.32)
      ..close();
    canvas.drawPath(leftHand, handPaint);
    canvas.drawPath(leftHand, handShadow);

    // Right Hand
    final rightHand = Path()
      ..moveTo(cx + r * 0.52, cy + r * 0.2)
      ..quadraticBezierTo(cx + r * 0.32, cy - r * 0.2, cx + r * 0.10, cy - r * 0.02)
      ..quadraticBezierTo(cx + r * 0.15, cy + r * 0.22, cx + r * 0.45, cy + r * 0.32)
      ..close();
    canvas.drawPath(rightHand, handPaint);
    canvas.drawPath(rightHand, handShadow);

    // Blushing anime lines
    final blush = Paint()
      ..color = const Color(0xFFF43F5E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawLine(Offset(cx - 8, cy + r * 0.18), Offset(cx - 3, cy + r * 0.25), blush);
    canvas.drawLine(Offset(cx + 3, cy + r * 0.18), Offset(cx + 8, cy + r * 0.25), blush);
  }

  void _drawPeekingHands(Canvas canvas, double hx, double hy, double r) {
    // Vertical card edge rail that the fingers grip (Olena Kychun reference)
    final railColor = state == SunnyState.adminShield
        ? const Color(0xFF00F0FF)
        : (state == SunnyState.wavingRight ? const Color(0xFF10B981) : const Color(0xFFF59E0B));
    final railPaint = Paint()
      ..color = railColor
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(hx + r * 0.38, hy - r * 0.35),
      Offset(hx + r * 0.38, hy + r * 0.45),
      railPaint,
    );

    // Hands gripping the card border
    final handPaint = Paint()..color = const Color(0xFFFFD7BE);
    final handBorder = Paint()
      ..color = const Color(0xFFF5BA93)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (int i = 0; i < 3; i++) {
      final fy = hy + (i * r * 0.12);
      final finger = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(hx + r * 0.35, fy), width: r * 0.36, height: r * 0.10),
        const Radius.circular(8),
      );
      canvas.drawRRect(finger, handPaint);
      canvas.drawRRect(finger, handBorder);
      // Fingernail / highlight accent
      canvas.drawCircle(Offset(hx + r * 0.46, fy), r * 0.04, Paint()..color = const Color(0xFFFFF0E5));
    }
  }

  void _drawWavingArm(Canvas canvas, double ax, double ay, double r, double angle) {
    // Cheerful waving arm (Olena Kychun reference)
    canvas.save();
    canvas.translate(ax, ay + r * 0.15);
    canvas.rotate(angle);

    final armPaint = Paint()..color = const Color(0xFFFFD7BE);
    final armBorder = Paint()
      ..color = const Color(0xFFF5BA93)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final armPath = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(r * 0.22, -r * 0.38, r * 0.38, -r * 0.48)
      ..lineTo(r * 0.48, -r * 0.42)
      ..quadraticBezierTo(r * 0.28, -r * 0.22, r * 0.12, 0.05)
      ..close();
    canvas.drawPath(armPath, armPaint);
    canvas.drawPath(armPath, armBorder);

    final handCenter = Offset(r * 0.42, -r * 0.52);
    canvas.drawCircle(handCenter, r * 0.15, armPaint);
    canvas.drawCircle(handCenter, r * 0.15, armBorder);

    for (int i = 0; i < 4; i++) {
      final fAngle = (i - 1.5) * 0.28;
      final fx = handCenter.dx + math.cos(fAngle - math.pi / 2) * r * 0.16;
      final fy = handCenter.dy + math.sin(fAngle - math.pi / 2) * r * 0.16;
      canvas.drawCircle(Offset(fx, fy), r * 0.055, armPaint);
      canvas.drawCircle(Offset(fx, fy), r * 0.055, armBorder);
    }
    canvas.restore();
  }

  void _drawCelebratingArms(Canvas canvas, double cx, double cy, double r, double wave) {
    final armPaint = Paint()..color = const Color(0xFFFFD7BE);
    canvas.drawCircle(Offset(cx - r * 0.8, cy - r * 0.4 + (wave * 12)), r * 0.14, armPaint);
    canvas.drawCircle(Offset(cx + r * 0.8, cy - r * 0.4 - (wave * 12)), r * 0.14, armPaint);
  }

  void _drawAdminVisor(Canvas canvas, double cx, double cy, double r) {
    final visorPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF00F0FF), Color(0xFF0284C7)],
      ).createShader(Rect.fromLTWH(cx - r * 0.45, cy - r * 0.15, r * 0.9, r * 0.25));

    final visorRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy - r * 0.04), width: r * 0.9, height: r * 0.24),
      const Radius.circular(12),
    );
    canvas.drawRRect(visorRect, visorPaint);

    final scanLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(cx - r * 0.38, cy - r * 0.07), Offset(cx + r * 0.38, cy - r * 0.07), scanLine);
  }

  @override
  bool shouldRepaint(covariant _SunnyMascotPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.breathY != breathY ||
        oldDelegate.waveAngle != waveAngle ||
        oldDelegate.isBlinking != isBlinking ||
        oldDelegate.lookProgress != lookProgress;
  }
}
