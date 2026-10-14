import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme.dart';

/// The spinning pixel-art globe from the reference.
class PixelGlobe extends StatefulWidget {
  const PixelGlobe({super.key, required this.size, this.color = DD.ink});

  final double size;
  final Color color;

  @override
  State<PixelGlobe> createState() => _PixelGlobeState();
}

class _PixelGlobeState extends State<PixelGlobe> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 7))
    ..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(size: Size.square(widget.size), painter: _GlobePainter(_spin, widget.color)),
    );
  }
}

class _GlobePainter extends CustomPainter {
  _GlobePainter(this.spin, this.color) : super(repaint: spin);

  final Animation<double> spin;
  final Color color;
  static const n = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final px = size.width / n;
    final paint = Paint()..color = color;
    final phase = spin.value * math.pi * 2;
    final cell = 2 / n;

    for (var j = 0; j < n; j++) {
      final y = (j + 0.5) * cell - 1;
      for (var i = 0; i < n; i++) {
        final x = (i + 0.5) * cell - 1;
        final r = math.sqrt(x * x + y * y);
        if (r > 1.04) continue;
        var on = r > 1 - cell * 1.6; // heavy outline ring (2 cells)
        if (!on && y.abs() < cell * 0.95) on = true; // thick equator
        if (!on) {
          // Four meridians, projected to screen space (front side only).
          final halfWidth = math.sqrt(math.max(0, 1 - y * y));
          for (var k = 0; k < 4 && !on; k++) {
            final a = phase + k * math.pi / 2;
            if (math.cos(a) <= 0.05) continue;
            final mx = math.sin(a) * halfWidth;
            if ((x - mx).abs() < cell * 0.9) on = true;
          }
        }
        if (on) {
          canvas.drawRect(Rect.fromLTWH(i * px, j * px, px * 0.98, px * 0.98), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_GlobePainter old) => old.color != color;
}
