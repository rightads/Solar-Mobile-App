import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:solar_pro/core/theme/app_theme.dart';

// Procedural, animated pixel-art illustrations for SolarPro.
//
// Every scene is drawn on a coarse logical grid (e.g. 60×40 cells) and scaled
// to fit, so the art stays crisp at any size and needs no raster assets.

class PixelPalette {
  PixelPalette._();
  static const ink       = Color(0xFF2A1E6B);
  static const sunCore   = Color(0xFFFFB020);
  static const sunLight  = Color(0xFFFFD45E);
  static const sunShade  = Color(0xFFF28A00);
  static const panel     = Color(0xFF3E4FC9);
  static const panelLit  = Color(0xFF6274F2);
  static const panelLine = Color(0xFFB9C3FF);
  static const glare     = Color(0xFFE4E8FF);
  static const wall      = Color(0xFFFFE6C2);
  static const wallShade = Color(0xFFF4C88E);
  static const roof      = Color(0xFFE8743B);
  static const roofDark  = Color(0xFFB9542A);
  static const door      = Color(0xFF8A5A3C);
  static const window    = Color(0xFF9FD8F5);
  static const grass     = Color(0xFF6CC24A);
  static const grassDark = Color(0xFF3E9B35);
  static const trunk     = Color(0xFF7A4B2A);
  static const cloud     = Color(0xFFFFFFFF);
  static const cloudEdge = Color(0xFFDCD5F7);
  static const faint     = Color(0xFFE3DDF8);
  static const ocean     = Color(0xFF4D8FE8);
  static const oceanDark = Color(0xFF346FC4);
  static const land      = Color(0xFF6CC24A);
  static const landDark  = Color(0xFF4A9E36);
  static const screen    = Color(0xFFF3F1FF);
  static const metal     = Color(0xFFD9D4EE);
  static const bar       = Color(0xFF5B6CF0);
  static const white     = Color(0xFFFFFFFF);
}

/// Grid-snapped drawing helpers over a [Canvas].
class PixelGrid {
  final Canvas canvas;
  final double u;
  final Offset origin;
  final Paint _p = Paint()..isAntiAlias = false;

  PixelGrid(this.canvas, this.u, this.origin);

  /// Fits a [cols]×[rows] grid inside [size], centred (or bottom-anchored).
  factory PixelGrid.fit(Canvas canvas, Size size, int cols, int rows, {bool bottom = false}) {
    final u = math.min(size.width / cols, size.height / rows);
    final dx = (size.width - cols * u) / 2;
    final dy = bottom ? size.height - rows * u : (size.height - rows * u) / 2;
    return PixelGrid(canvas, u, Offset(dx, dy));
  }

  void px(num x, num y, Color c) {
    _p.color = c;
    canvas.drawRect(
      Rect.fromLTWH(origin.dx + x.floor() * u, origin.dy + y.floor() * u, u + 0.35, u + 0.35),
      _p,
    );
  }

  void rect(num x, num y, num w, num h, Color c) {
    if (w <= 0 || h <= 0) return;
    _p.color = c;
    canvas.drawRect(
      Rect.fromLTWH(origin.dx + x.floor() * u, origin.dy + y.floor() * u, w.floor() * u + 0.35, h.floor() * u + 0.35),
      _p,
    );
  }

  /// Rect with a 1-cell ink outline.
  void box(num x, num y, num w, num h, Color fill, {Color outline = PixelPalette.ink}) {
    rect(x, y, w, h, outline);
    rect(x + 1, y + 1, w - 2, h - 2, fill);
  }

  /// Rasterised filled disk; [shade] can vary colour per cell.
  void disk(num cx, num cy, num r, Color c, {Color Function(int dx, int dy)? shade, bool outline = false}) {
    final ri = r.ceil();
    for (int dy = -ri; dy <= ri; dy++) {
      for (int dx = -ri; dx <= ri; dx++) {
        final d = (dx + 0.5) * (dx + 0.5) + (dy + 0.5) * (dy + 0.5);
        if (d <= r * r) {
          final edge = outline && d > (r - 1.1) * (r - 1.1);
          px(cx + dx, cy + dy, edge ? PixelPalette.ink : (shade?.call(dx, dy) ?? c));
        }
      }
    }
  }

  /// Bresenham line.
  void line(int x0, int y0, int x1, int y1, Color c) {
    int dx = (x1 - x0).abs(), sx = x0 < x1 ? 1 : -1;
    int dy = -(y1 - y0).abs(), sy = y0 < y1 ? 1 : -1;
    int err = dx + dy;
    while (true) {
      px(x0, y0, c);
      if (x0 == x1 && y0 == y1) break;
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        x0 += sx;
      }
      if (e2 <= dx) {
        err += dx;
        y0 += sy;
      }
    }
  }

  /// Fluffy cloud built from overlapping disks.
  void cloud(num x, num y, {double s = 1, Color fill = PixelPalette.cloud, Color edge = PixelPalette.cloudEdge}) {
    final parts = [
      [0.0, 2.0, 3.0],
      [4.0, 0.0, 4.0],
      [9.0, 1.5, 3.2],
      [12.0, 3.0, 2.4],
    ];
    for (final p in parts) {
      disk(x + p[0] * s, y + p[1] * s + 0.6, p[2] * s + 0.6, edge);
    }
    for (final p in parts) {
      disk(x + p[0] * s, y + p[1] * s, p[2] * s, fill);
    }
    rect(x - 2 * s, y + 3.4 * s, 16.5 * s, 1.6 * s, fill);
  }

  /// 4-point twinkle; [phase] 0..1 controls arm length.
  void sparkle(num x, num y, double phase, Color c) {
    final arm = (math.sin(phase * math.pi * 2) * 1.5 + 1.5).round();
    px(x, y, c);
    for (int i = 1; i <= arm; i++) {
      px(x + i, y, c);
      px(x - i, y, c);
      px(x, y + i, c);
      px(x, y - i, c);
    }
  }

  /// Tilted solar panel: [cols]×[rows] cells, each row shifted by [skew].
  /// [glare] (0..1) sweeps a highlight band across the face.
  void panel(num x, num y, int cols, int rows, {double skew = 0.5, double glare = -1}) {
    for (int r = 0; r < rows; r++) {
      final shift = ((rows - r) * skew).round();
      for (int c = 0; c < cols; c++) {
        final edge = r == 0 || r == rows - 1 || c == 0 || c == cols - 1;
        Color col;
        if (edge) {
          col = PixelPalette.ink;
        } else if (c % 4 == 0 || r % 3 == 0) {
          col = PixelPalette.panelLine;
        } else {
          col = (c + r).isEven ? PixelPalette.panel : PixelPalette.panelLit;
        }
        if (!edge && glare >= 0) {
          final band = (c + r) / (cols + rows);
          if ((band - glare).abs() < 0.06) col = PixelPalette.glare;
        }
        px(x + c + shift, y + r, col);
      }
    }
  }

  /// Sun with pulsing rays. [t] 0..1 loops.
  void sun(num cx, num cy, num r, double t, {bool rays = true}) {
    if (rays) {
      final len = 2 + (math.sin(t * math.pi * 2) * 1.2).round();
      for (int i = 0; i < 8; i++) {
        final a = i * math.pi / 4 + t * math.pi / 8;
        final x0 = (cx + math.cos(a) * (r + 2)).round();
        final y0 = (cy + math.sin(a) * (r + 2)).round();
        final x1 = (cx + math.cos(a) * (r + 2 + len)).round();
        final y1 = (cy + math.sin(a) * (r + 2 + len)).round();
        line(x0, y0, x1, y1, PixelPalette.sunCore);
      }
    }
    disk(cx, cy, r, PixelPalette.sunCore, shade: (dx, dy) {
      if (dx + dy < -r * 0.6) return PixelPalette.sunLight;
      if (dx + dy > r * 0.7) return PixelPalette.sunShade;
      return PixelPalette.sunCore;
    });
  }

  void tree(num x, num groundY, {int h = 6}) {
    rect(x, groundY - 3, 2, 3, PixelPalette.trunk);
    disk(x + 1, groundY - 3 - h / 2, h / 2 + 1, PixelPalette.grassDark);
    disk(x + 0.5, groundY - 4 - h / 2, h / 2, PixelPalette.grass);
  }
}

// ─── Animated host ───────────────────────────────────────────────────────────
typedef PixelScenePainter = void Function(PixelGrid g, double t, Size size);

/// Hosts a looping pixel scene. [period] is one full animation loop.
class PixelScene extends StatefulWidget {
  final int cols;
  final int rows;
  final PixelScenePainter painter;
  final Duration period;
  final bool bottomAnchor;
  final bool animate;

  const PixelScene({
    super.key,
    required this.cols,
    required this.rows,
    required this.painter,
    this.period = const Duration(seconds: 6),
    this.bottomAnchor = false,
    this.animate = true,
  });

  @override
  State<PixelScene> createState() => _PixelSceneState();
}

class _PixelSceneState extends State<PixelScene> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScenePainter(widget, _c),
      ),
    );
  }
}

class _ScenePainter extends CustomPainter {
  final PixelScene w;
  final Animation<double> anim;
  _ScenePainter(this.w, this.anim) : super(repaint: anim);

  @override
  void paint(Canvas canvas, Size size) {
    final g = PixelGrid.fit(canvas, size, w.cols, w.rows, bottom: w.bottomAnchor);
    w.painter(g, anim.value, size);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) => old.w.painter != w.painter;
}

// ─── Scenes ──────────────────────────────────────────────────────────────────
class PixelScenes {
  PixelScenes._();

  /// Sun above a tilted panel — the splash / brand hero.
  static Widget sunPanel({double? width, double? height}) => SizedBox(
        width: width,
        height: height,
        child: PixelScene(
          cols: 40,
          rows: 30,
          painter: (g, t, _) {
            g.sun(20, 8, 5, t);
            g.sparkle(6, 6, t, PixelPalette.faint);
            g.sparkle(34, 4, (t + 0.5) % 1, PixelPalette.faint);
            g.panel(6, 16, 26, 9, skew: 0.45, glare: t);
            g.rect(14, 25, 2, 4, PixelPalette.ink);
            g.rect(26, 25, 2, 4, PixelPalette.ink);
          },
        ),
      );

  /// Setting sun behind panel rows, trees and grass — ground strip.
  static Widget landscape({double height = 140}) => SizedBox(
        height: height,
        width: double.infinity,
        child: PixelScene(
          cols: 64,
          rows: 30,
          bottomAnchor: true,
          period: const Duration(seconds: 8),
          painter: (g, t, _) {
            g.cloud(4 + (t * 10) % 8, 3, s: 0.8);
            g.sun(40, 15, 10, t, rays: false);
            g.rect(0, 22, 64, 8, PixelPalette.grass);
            g.rect(0, 22, 64, 1, PixelPalette.grassDark);
            g.tree(4, 22, h: 8);
            g.tree(58, 22, h: 6);
            g.panel(14, 15, 22, 7, skew: 0.5, glare: t);
            g.panel(36, 18, 20, 6, skew: 0.5, glare: (t + 0.3) % 1);
            for (int i = 0; i < 64; i += 5) {
              g.px(i + 2, 24 + (i % 3), PixelPalette.grassDark);
            }
          },
        ),
      );

  /// House with rooftop panels, wind turbine, tree and drifting clouds.
  static Widget house({double? height, double? width}) => SizedBox(
        height: height,
        width: width,
        child: PixelScene(
          cols: 60,
          rows: 40,
          period: const Duration(seconds: 10),
          painter: (g, t, _) {
            final drift = (t * 60) % 76 - 14;
            g.cloud(drift, 4, s: 0.7);
            g.cloud((drift + 38) % 76 - 14, 9, s: 0.5);
            g.sun(49, 8, 4, t);

            // Wind turbine
            g.rect(9, 14, 1, 20, PixelPalette.metal);
            final a = t * math.pi * 6;
            for (int i = 0; i < 3; i++) {
              final ang = a + i * math.pi * 2 / 3;
              g.line(9, 13, (9 + math.cos(ang) * 6).round(), (13 + math.sin(ang) * 6).round(), PixelPalette.ink);
            }
            g.px(9, 13, PixelPalette.sunShade);

            // House body
            g.box(22, 22, 26, 12, PixelPalette.wall);
            g.rect(23, 23, 3, 10, PixelPalette.wallShade);
            g.box(32, 26, 6, 8, PixelPalette.door);
            g.box(25, 25, 5, 5, PixelPalette.window);
            g.box(40, 25, 5, 5, PixelPalette.window);
            // Roof (stepped gable) with panels on its face
            for (int r = 0; r < 9; r++) {
              final w = 30 - r * 2;
              g.rect(20 + r, 21 - r, w, 1, r == 0 ? PixelPalette.roofDark : PixelPalette.roof);
            }
            g.panel(25, 14, 18, 6, skew: 0.0, glare: t);

            // Ground + tree
            g.rect(0, 34, 60, 6, PixelPalette.grass);
            g.rect(0, 34, 60, 1, PixelPalette.grassDark);
            g.tree(52, 34, h: 8);
            g.tree(16, 34, h: 5);
            g.sparkle(4, 4, t, PixelPalette.faint);
          },
        ),
      );

  /// Dashboard monitor with a bolt and rising bar chart.
  static Widget monitor({double? height, double? width}) => SizedBox(
        height: height,
        width: width,
        child: PixelScene(
          cols: 48,
          rows: 40,
          period: const Duration(seconds: 4),
          painter: (g, t, _) {
            g.cloud(2, 4, s: 0.6);
            g.cloud(32, 30, s: 0.5);
            g.box(6, 6, 36, 26, PixelPalette.metal);
            g.rect(8, 8, 32, 22, PixelPalette.screen);
            for (int i = 0; i < 3; i++) {
              g.px(10 + i * 2, 9, [PixelPalette.roof, PixelPalette.sunCore, PixelPalette.grass][i]);
            }
            // Bolt
            const bolt = [
              [16, 12], [15, 13], [14, 14], [13, 15], [13, 16], [14, 16], [15, 16], [16, 16],
              [15, 17], [14, 18], [13, 19], [17, 13], [16, 14], [15, 15],
            ];
            for (final b in bolt) {
              g.px(b[0], b[1], PixelPalette.sunCore);
            }
            // Bars rising in a loop
            const heights = [4, 7, 10, 14];
            for (int i = 0; i < heights.length; i++) {
              final grow = Curves.easeOutBack.transform(((t * 1.6 - i * 0.12).clamp(0.0, 1.0)));
              final h = (heights[i] * grow).round();
              g.rect(22 + i * 4, 27 - h, 3, h, PixelPalette.bar);
            }
            g.rect(21, 27, 17, 1, PixelPalette.ink);
            g.rect(20, 32, 8, 3, PixelPalette.metal);
            g.rect(16, 35, 16, 1, PixelPalette.ink);
            g.sparkle(44, 6, t, PixelPalette.sunCore);
            g.sparkle(3, 22, (t + 0.4) % 1, PixelPalette.faint);
          },
        ),
      );

  /// Rotating earth with a sprouting plant.
  static Widget earth({double? height, double? width}) => SizedBox(
        height: height,
        width: width,
        child: PixelScene(
          cols: 48,
          rows: 44,
          period: const Duration(seconds: 7),
          painter: (g, t, _) {
            g.cloud(1, 8, s: 0.55);
            g.cloud(34, 26, s: 0.5);
            const cx = 24, cy = 28, r = 13.0;
            final spin = (t * 26).floor();
            g.disk(cx, cy, r, PixelPalette.ocean, outline: true, shade: (dx, dy) {
              final lx = (dx + spin + 40) % 26;
              final ly = dy + 13;
              final landHit = ((lx > 3 && lx < 10 && ly > 5 && ly < 14) ||
                  (lx > 14 && lx < 22 && ly > 12 && ly < 22) ||
                  (lx > 8 && lx < 13 && ly > 18 && ly < 24));
              if (landHit) return dx + dy > 8 ? PixelPalette.landDark : PixelPalette.land;
              return dx + dy > 10 ? PixelPalette.oceanDark : PixelPalette.ocean;
            });
            // Sprout grows in the first half, sways after.
            final grow = Curves.easeOutBack.transform((t * 2).clamp(0.0, 1.0));
            final stem = (6 * grow).round();
            g.rect(cx, cy - 13 - stem, 1, stem, PixelPalette.grassDark);
            if (grow > 0.6) {
              final sway = (math.sin(t * math.pi * 4)).round();
              g.disk(cx - 3 + sway, cy - 13 - stem, 2.4, PixelPalette.grass);
              g.disk(cx + 4 + sway, cy - 14 - stem, 2.8, PixelPalette.grass);
            }
            g.sparkle(8, 20, t, PixelPalette.sunCore);
            g.sparkle(41, 14, (t + 0.5) % 1, PixelPalette.sunCore);
          },
        ),
      );

  /// Small sun + cloud badge used on the OTP screen.
  static Widget sunCloud({double size = 72}) => SizedBox(
        width: size * 1.4,
        height: size,
        child: PixelScene(
          cols: 28,
          rows: 20,
          period: const Duration(seconds: 5),
          painter: (g, t, _) {
            g.sun(11, 9, 5, t);
            g.cloud(12 + math.sin(t * math.pi * 2) * 1.5, 11, s: 0.6);
            g.line(15, 5, 13, 8, PixelPalette.sunShade);
            g.line(13, 8, 16, 8, PixelPalette.sunShade);
            g.line(16, 8, 14, 11, PixelPalette.sunShade);
          },
        ),
      );
}

// ─── Backdrop ────────────────────────────────────────────────────────────────
/// Lavender canvas with faint drifting pixel clouds, twinkles and specks —
/// the ambient background shared by auth screens and dashboards.
class PixelBackdrop extends StatelessWidget {
  final Widget? child;
  final Color color;
  final int seed;
  const PixelBackdrop({super.key, this.child, this.color = const Color(0xFFF6F4FD), this.seed = 7});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: color)),
        Positioned.fill(
          child: IgnorePointer(
            child: PixelScene(
              cols: 90,
              rows: 160,
              period: const Duration(seconds: 40),
              painter: (g, t, size) {
                final rnd = math.Random(seed);
                for (int i = 0; i < 5; i++) {
                  final y = 8 + rnd.nextInt(140);
                  final speed = 0.6 + rnd.nextDouble();
                  final x = ((rnd.nextDouble() * 110 + t * 110 * speed) % 120) - 18;
                  g.cloud(x, y, s: 0.5 + rnd.nextDouble() * 0.5, fill: const Color(0xFFEDE8FC), edge: const Color(0xFFE6E0FA));
                }
                for (int i = 0; i < 12; i++) {
                  final x = rnd.nextInt(90), y = rnd.nextInt(160);
                  g.sparkle(x, y, (t * 6 + i / 12) % 1, const Color(0xFFE2DBFA));
                }
                for (int i = 0; i < 16; i++) {
                  final x = rnd.nextInt(90), y = rnd.nextInt(160);
                  g.rect(x, y, 2, 2, const Color(0xFFEDE9FB));
                }
              },
            ),
          ),
        ),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

// ─── Brand mark ──────────────────────────────────────────────────────────────
/// "⚡ SolarPro" lockup with a pixel bolt that flickers on a loop.
class SolarProLogo extends StatelessWidget {
  final double size;
  final TextStyle? textStyle;
  const SolarProLogo({super.key, this.size = 22, this.textStyle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size * 1.1,
          height: size * 1.25,
          child: PixelScene(
            cols: 11,
            rows: 13,
            period: const Duration(milliseconds: 2400),
            painter: (g, t, _) {
              const cells = [
                [7, 0], [8, 0], [6, 1], [7, 1], [5, 2], [6, 2], [4, 3], [5, 3], [3, 4], [4, 4],
                [2, 5], [3, 5], [4, 5], [5, 5], [6, 5], [7, 5], [8, 5], [6, 6], [7, 6], [5, 7],
                [6, 7], [4, 8], [5, 8], [3, 9], [4, 9], [2, 10], [3, 10], [2, 11],
              ];
              final flash = t > 0.86 && t < 0.92;
              for (final c in cells) {
                g.px(c[0] + 1, c[1] + 1, PixelPalette.ink);
              }
              for (final c in cells) {
                g.px(c[0], c[1], flash ? PixelPalette.sunLight : PixelPalette.sunCore);
              }
              g.px(8, 0, PixelPalette.sunLight);
              g.px(1, 2, PixelPalette.sunShade);
              g.px(9, 8, PixelPalette.sunShade);
            },
          ),
        ),
        SizedBox(width: size * 0.3),
        Text(
          'SolarPro',
          style: textStyle ?? AppTextStyles.pixel.copyWith(fontSize: size, color: PixelPalette.ink),
        ),
      ],
    );
  }
}
