import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme.dart';

double _iv(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

/// Sparse dot grid on the timeline background.
class DotGrid extends StatelessWidget {
  const DotGrid({super.key, required this.scale, this.offset = 0});

  final double scale;

  /// Scroll offset — the grid drifts slower than the items for depth.
  final double offset;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _DotGridPainter(scale, offset), size: Size.infinite),
  );
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter(this.s, this.offset);
  final double s, offset;

  @override
  void paint(Canvas canvas, Size size) {
    final step = 38 * s;
    final paint = Paint()..color = DD.dot;
    final shift = -(offset * 0.35) % step;
    for (var y = shift + step * 0.4; y < size.height + step; y += step) {
      for (var x = step * 0.55; x < size.width; x += step) {
        canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: 1.6 * s, height: 1.6 * s), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.offset != offset || old.s != s;
}

/// The black "HI JACK" capsule with avatar and the lightning button.
/// [intro] 0..1 plays the line → capsule → tall pill build-up.
class UserPill extends StatelessWidget {
  const UserPill({
    super.key,
    required this.scale,
    required this.intro,
    required this.name,
    required this.onAvatar,
    required this.onBolt,
  });

  final double scale, intro;
  final String name;
  final VoidCallback onAvatar, onBolt;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final a = Curves.easeOutCubic.transform(_iv(intro, 0.0, 0.3));
    final b = Curves.easeInOutCubic.transform(_iv(intro, 0.3, 0.55));
    final c = Curves.easeOutBack.transform(_iv(intro, 0.55, 1.0));
    final w = lerpDouble(lerpDouble(0, 44 * s, a), 62 * s, b)!;
    final h = lerpDouble(lerpDouble(3.5 * s, 22 * s, b), 128 * s, c)!;
    final contentOpacity = _iv(intro, 0.7, 1.0);
    final labelOpacity = math.max(_iv(intro, 0.42, 0.55) * (1 - _iv(intro, 0.55, 0.7)), contentOpacity);

    return SizedBox(
      width: 62 * s,
      height: 128 * s,
      child: Align(
        alignment: Alignment.topRight,
        child: Container(
          width: w,
          height: math.max(h, 0),
          decoration: BoxDecoration(color: DD.ink, borderRadius: BorderRadius.circular(31 * s)),
          clipBehavior: Clip.antiAlias,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            maxHeight: 128 * s,
            minHeight: 128 * s,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // Avatar.
                Positioned(
                  top: 7 * s,
                  child: Opacity(
                    opacity: contentOpacity,
                    child: GestureDetector(
                      onTap: onAvatar,
                      child: _Avatar(size: 46 * s),
                    ),
                  ),
                ),
                // Name.
                Positioned(
                  top: c > 0 ? lerpDouble(5 * s, 58 * s, c) : 5 * s,
                  child: Opacity(
                    opacity: labelOpacity.clamp(0.0, 1.0),
                    child: Text(
                      'HI ${name.split(' ').first}',
                      maxLines: 1,
                      style: DD.mono(7.2 * s, weight: FontWeight.w400, color: Colors.white, spacing: 0.3),
                    ),
                  ),
                ),
                // Bolt.
                Positioned(
                  bottom: 8 * s,
                  child: Opacity(
                    opacity: contentOpacity,
                    child: Transform.scale(
                      scale: lerpDouble(0.6, 1, contentOpacity),
                      child: GestureDetector(
                        onTap: onBolt,
                        child: _BoltButton(size: 44 * s),
                      ),
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  radius: 1.1,
                  colors: [Color(0xFFD8D7DC), Color(0xFF9A99A0)],
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: CustomPaint(painter: _SilhouettePainter()),
            ),
          ),
          Positioned(
            right: size * 0.02,
            bottom: size * 0.1,
            child: Container(
              width: size * 0.09,
              height: size * 0.09,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
        ],
      ),
    );
  }
}

/// Head-and-shoulders profile silhouette for the default avatar.
class _SilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Path()
      ..moveTo(w * 0.30, h * 1.0)
      ..cubicTo(w * 0.28, h * 0.82, w * 0.36, h * 0.74, w * 0.40, h * 0.70)
      ..cubicTo(w * 0.30, h * 0.62, w * 0.28, h * 0.44, w * 0.34, h * 0.32)
      ..cubicTo(w * 0.42, h * 0.16, w * 0.66, h * 0.16, w * 0.70, h * 0.34)
      ..lineTo(w * 0.75, h * 0.47)
      ..lineTo(w * 0.70, h * 0.50)
      ..cubicTo(w * 0.70, h * 0.60, w * 0.66, h * 0.66, w * 0.60, h * 0.66)
      ..lineTo(w * 0.60, h * 0.74)
      ..cubicTo(w * 0.78, h * 0.78, w * 0.90, h * 0.86, w * 0.94, h * 1.0)
      ..close();
    canvas.drawPath(p, Paint()..color = const Color(0xFF141416));
  }

  @override
  bool shouldRepaint(_SilhouettePainter old) => false;
}

class _BoltButton extends StatelessWidget {
  const _BoltButton({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.5,
        height: size * 0.5,
        decoration: const BoxDecoration(color: DD.ink, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(Icons.bolt_rounded, size: size * 0.36, color: Colors.white),
      ),
    );
  }
}

/// The black notch that bites into the right edge of the screen.
class SideTab extends StatelessWidget {
  const SideTab({
    super.key,
    required this.scale,
    required this.expanded,
    required this.onExpand,
    required this.onArchive,
    required this.onAdd,
  });

  final double scale;
  final bool expanded;
  final VoidCallback onExpand, onArchive, onAdd;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    Widget button(IconData icon, VoidCallback onTap, double size) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 34 * s,
        height: 40 * s,
        child: Icon(icon, size: size * s, color: Colors.white),
      ),
    );
    return CustomPaint(
      painter: _SideTabPainter(s),
      child: SizedBox(
        width: 36 * s,
        height: 204 * s,
        child: Padding(
          padding: EdgeInsets.only(left: 6 * s),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              button(expanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, onExpand, 17),
              button(Icons.folder_rounded, onArchive, 15),
              button(Icons.add_to_photos_outlined, onAdd, 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideTabPainter extends CustomPainter {
  _SideTabPainter(this.s);
  final double s;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final inset = 4 * s; // vertical edge of the notch
    final cut = 30 * s; // height of the diagonal shoulders
    final r = 7 * s;
    final path = Path()
      ..moveTo(w, 0)
      ..lineTo(w, h)
      ..cubicTo(w, h - r * 0.6, w - r * 0.4, h - r, w - r * 0.9, h - r * 1.2)
      ..lineTo(inset + r * 0.5, h - cut + r * 0.4)
      ..quadraticBezierTo(inset, h - cut, inset, h - cut - r)
      ..lineTo(inset, cut + r)
      ..quadraticBezierTo(inset, cut, inset + r * 0.5, cut - r * 0.4)
      ..lineTo(w - r * 0.9, r * 1.2)
      ..cubicTo(w - r * 0.4, r, w, r * 0.6, w, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = DD.ink);
  }

  @override
  bool shouldRepaint(_SideTabPainter old) => old.s != s;
}

/// Frosted bottom bar: menu, EXPLORE, the day scrubber and the entry count.
class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.scale,
    required this.value,
    required this.count,
    required this.onMenu,
    required this.onExplore,
    required this.onScrub,
    required this.onScrubEnd,
  });

  final double scale;

  /// 0..1 position of the scrubber thumb.
  final double value;
  final int count;
  final VoidCallback onMenu, onExplore;
  final ValueChanged<double> onScrub;
  final VoidCallback onScrubEnd;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    return Container(
      height: 58 * s,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.93),
        borderRadius: BorderRadius.circular(13 * s),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 18 * s, offset: Offset(0, 4 * s)),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onMenu,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16 * s, 16 * s, 12 * s, 16 * s),
              child: CustomPaint(size: Size(18 * s, 7 * s), painter: _MenuPainter(s)),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onExplore,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16 * s),
              child: Text('EXPLORE', style: DD.mono(7.4 * s, weight: FontWeight.w400, spacing: 0.2)),
            ),
          ),
          SizedBox(width: 26 * s),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) {
                void scrub(double dx) => onScrub(((dx - 8 * s) / (box.maxWidth - 16 * s)).clamp(0.0, 1.0));
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (d) => scrub(d.localPosition.dx),
                  onHorizontalDragUpdate: (d) => scrub(d.localPosition.dx),
                  onHorizontalDragEnd: (_) => onScrubEnd(),
                  onTapUp: (d) {
                    scrub(d.localPosition.dx);
                    onScrubEnd();
                  },
                  child: CustomPaint(
                    size: Size(box.maxWidth, 58 * s),
                    painter: _ScrubPainter(s, value, '${two(count)} X'),
                  ),
                );
              },
            ),
          ),
          SizedBox(width: 14 * s),
        ],
      ),
    );
  }
}

class _MenuPainter extends CustomPainter {
  _MenuPainter(this.s);
  final double s;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = DD.ink
      ..strokeWidth = 1.3 * s;
    canvas.drawLine(Offset(0, 0.5 * s), Offset(size.width, 0.5 * s), p);
    canvas.drawLine(Offset(0, size.height - 0.5 * s), Offset(size.width, size.height - 0.5 * s), p);
  }

  @override
  bool shouldRepaint(_MenuPainter old) => false;
}

class _ScrubPainter extends CustomPainter {
  _ScrubPainter(this.s, this.value, this.label);
  final double s, value;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2 - 2 * s;
    final x0 = 1.5 * s, x1 = size.width - 1.5 * s;
    final dot = Paint()..color = DD.ink;
    void bracket(double x) {
      for (final dy in [-5.5 * s, 5.5 * s]) {
        canvas.drawRect(Rect.fromCenter(center: Offset(x, cy + dy), width: 3 * s, height: 3 * s), dot);
      }
    }

    bracket(x0);
    bracket(x1);
    final a = x0 + 7 * s, b = x1 - 7 * s;
    final tx = a + (b - a) * value.clamp(0.0, 1.0);
    canvas.drawLine(
      Offset(a, cy),
      Offset(tx, cy),
      Paint()
        ..color = DD.ink
        ..strokeWidth = 1.3 * s,
    );
    canvas.drawLine(
      Offset(tx, cy),
      Offset(b, cy),
      Paint()
        ..color = DD.line
        ..strokeWidth = 1 * s,
    );
    canvas.drawRect(Rect.fromCenter(center: Offset(tx, cy), width: 3.2 * s, height: 16 * s), dot);

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: DD.mono(7 * s, weight: FontWeight.w400),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x1 - 10 * s - tp.width, cy + 8 * s));
  }

  @override
  bool shouldRepaint(_ScrubPainter old) => old.value != value || old.label != label || old.s != s;
}
