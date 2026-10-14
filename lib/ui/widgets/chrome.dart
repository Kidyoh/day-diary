import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../theme.dart';

double _iv(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

// All geometry below is measured from the reference frame, flattened to a
// 393 × 852 screen, and scaled by `s` (= screen width / 393).

/// Sparse dot grid: 50.5pt pitch, first column at x 18.3, a row at y 181.
class DotGrid extends StatelessWidget {
  const DotGrid({super.key, required this.scale, this.offset = 0});

  final double scale;

  /// Scroll offset; the grid drifts at a third of the speed for depth.
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
    final step = 50.5 * s;
    final paint = Paint()..color = DD.dot;
    final y0 = (181 * s - offset * 0.33) % step;
    final dot = 1.7 * s;
    for (var y = y0 - step; y < size.height + step; y += step) {
      for (var x = 18.3 * s; x < size.width; x += step) {
        canvas.drawRect(Rect.fromCenter(center: Offset(x, y), width: dot, height: dot), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.offset != offset || old.s != s;
}

/// `HI MAYA` — first name only, short enough for the pill.
String pillGreeting(String name) {
  final first = name.trim().split(RegExp(r'\s+')).first.toUpperCase();
  if (first.isEmpty) return 'HELLO';
  return 'HI ${first.length > 6 ? first.substring(0, 6) : first}';
}

/// The black capsule (68 × 170) with avatar, greeting and the + button.
/// [intro] 0..1 plays the line → capsule → tall pill build-up.
class UserPill extends StatelessWidget {
  const UserPill({
    super.key,
    required this.scale,
    required this.intro,
    required this.name,
    required this.avatar,
    required this.onAvatar,
    required this.onAdd,
  });

  static const width = 68.0, height = 170.0;

  final double scale, intro;
  final String name;

  /// The user's profile photo; null shows the default silhouette.
  final ImageProvider? avatar;
  final VoidCallback onAvatar, onAdd;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    final a = Curves.easeOutCubic.transform(_iv(intro, 0.0, 0.3));
    final b = Curves.easeInOutCubic.transform(_iv(intro, 0.3, 0.55));
    final c = Curves.easeOutBack.transform(_iv(intro, 0.55, 1.0));
    final w = lerpDouble(lerpDouble(0, 48 * s, a), width * s, b)!;
    final h = lerpDouble(lerpDouble(3.5 * s, 24 * s, b), height * s, c)!;
    final contentOpacity = _iv(intro, 0.7, 1.0);
    final labelOpacity = math.max(_iv(intro, 0.42, 0.55) * (1 - _iv(intro, 0.55, 0.7)), contentOpacity);

    return SizedBox(
      width: width * s,
      height: height * s,
      child: Align(
        alignment: Alignment.topRight,
        child: Container(
          width: w,
          height: math.max(h, 0),
          decoration: BoxDecoration(color: DD.ink, borderRadius: BorderRadius.circular(34 * s)),
          clipBehavior: Clip.antiAlias,
          child: OverflowBox(
            alignment: Alignment.topCenter,
            maxHeight: height * s,
            minHeight: height * s,
            maxWidth: width * s,
            minWidth: width * s,
            child: Stack(
              children: [
                // Avatar: 45pt, 15pt from the top, centred at x 32.6.
                Positioned(
                  left: 10 * s,
                  top: 15.3 * s,
                  child: Opacity(
                    opacity: contentOpacity,
                    child: GestureDetector(
                      onTap: onAvatar,
                      child: Avatar(size: 45.3 * s, image: avatar),
                    ),
                  ),
                ),
                // Greeting: caps top at 73pt.
                Positioned(
                  left: 0,
                  right: 0,
                  top: lerpDouble(6.5 * s, 70.5 * s, c),
                  child: Opacity(
                    opacity: labelOpacity.clamp(0.0, 1.0),
                    child: Text(
                      pillGreeting(name),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: DD.mono(9.3 * s, weight: FontWeight.w400, color: Colors.white, height: 1.2),
                    ),
                  ),
                ),
                // + button: 47.5pt disc, 12.7pt from the bottom.
                Positioned(
                  left: 10.3 * s,
                  bottom: 12.7 * s,
                  child: Opacity(
                    opacity: contentOpacity,
                    child: Transform.scale(
                      scale: lerpDouble(0.6, 1, contentOpacity),
                      child: GestureDetector(
                        onTap: onAdd,
                        child: _AddButton(size: 47.5 * s),
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

/// Round profile photo, or a silhouette when none is set.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.size, this.image, this.dot = true});
  final double size;
  final ImageProvider? image;
  final bool dot;

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
              child: image == null
                  ? CustomPaint(painter: _SilhouettePainter())
                  : Image(image: image!, fit: BoxFit.cover, gaplessPlayback: true),
            ),
          ),
          if (dot)
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

/// White disc with a 23pt black core holding the glyph.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.485,
        height: size * 0.485,
        decoration: const BoxDecoration(color: DD.ink, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(Icons.add_rounded, size: size * 0.36, color: Colors.white),
      ),
    );
  }
}

/// The black notch (38 × 246) biting into the right edge of the screen:
/// 60pt diagonal shoulders, icons centred 16pt from the edge.
class SideTab extends StatelessWidget {
  const SideTab({
    super.key,
    required this.scale,
    required this.expanded,
    required this.onExpand,
    required this.onArchive,
    required this.onAdd,
  });

  static const width = 38.0, height = 246.0;

  final double scale;
  final bool expanded;
  final VoidCallback onExpand, onArchive, onAdd;

  @override
  Widget build(BuildContext context) {
    final s = scale;
    Widget button(double cy, IconData icon, VoidCallback onTap, double size) => Positioned(
      left: 0,
      right: 0,
      top: cy * s - 22 * s,
      height: 44 * s,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.only(left: 6 * s),
          child: Icon(icon, size: size * s, color: Colors.white),
        ),
      ),
    );
    return CustomPaint(
      painter: _SideTabPainter(s),
      child: SizedBox(
        width: width * s,
        height: height * s,
        child: Stack(
          children: [
            button(71, expanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, onExpand, 18),
            button(123.5, Icons.folder_rounded, onArchive, 17),
            button(174, Icons.add_to_photos_outlined, onAdd, 15),
          ],
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
    final cut = 60 * s; // height of each diagonal shoulder
    final r = 8 * s;
    final path = Path()
      ..moveTo(w, 0)
      ..quadraticBezierTo(w, r * 0.5, w - r * 0.7, r)
      ..lineTo(r * 0.6, cut - r)
      ..quadraticBezierTo(0, cut - r * 0.3, 0, cut + r * 0.6)
      ..lineTo(0, h - cut - r * 0.6)
      ..quadraticBezierTo(0, h - cut + r * 0.3, r * 0.6, h - cut + r)
      ..lineTo(w - r * 0.7, h - r)
      ..quadraticBezierTo(w, h - r * 0.5, w, h)
      ..close();
    canvas.drawPath(path, Paint()..color = DD.ink);
  }

  @override
  bool shouldRepaint(_SideTabPainter old) => old.s != s;
}

/// White bottom bar (64pt tall, 8pt side margins): menu, EXPLORE, the day
/// scrubber between two `:` brackets, and the entry count.
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

  static const height = 64.0;

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
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        // Bracket centres, relative to the bar (measured at 126.8 and 345.6
        // on a 378pt bar).
        final x0 = 126.8 * s, x1 = w - 32.4 * s;
        void scrub(double dx) => onScrub(((dx - x0) / (x1 - x0)).clamp(0.0, 1.0));
        return Container(
          height: height * s,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16 * s),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.025), blurRadius: 12 * s)],
          ),
          child: Stack(
            children: [
              // Menu: two 21pt lines, 7pt apart.
              Positioned(
                left: 13 * s,
                top: 0,
                bottom: 1.4 * s,
                width: 46 * s,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onMenu,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(left: 2 * s),
                      child: CustomPaint(size: Size(21 * s, 8.3 * s), painter: _MenuPainter(s)),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 61.5 * s,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onExplore,
                  child: Center(
                    child: Transform.translate(
                      offset: Offset(-0.5 * s, -1.5 * s),
                      child: Text('EXPLORE', style: DD.mono(7.8 * s, weight: FontWeight.w400, height: 1)),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: (d) => scrub(d.localPosition.dx),
                  onHorizontalDragUpdate: (d) => scrub(d.localPosition.dx),
                  onHorizontalDragEnd: (_) => onScrubEnd(),
                  child: IgnorePointer(child: CustomPaint(painter: _ScrubPainter(s, x0, x1, value, '${two(count)} X'))),
                ),
              ),
            ],
          ),
        );
      },
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
    canvas.drawLine(Offset(0, 0.65 * s), Offset(size.width, 0.65 * s), p);
    canvas.drawLine(Offset(0, size.height - 0.65 * s), Offset(size.width, size.height - 0.65 * s), p);
  }

  @override
  bool shouldRepaint(_MenuPainter old) => false;
}

class _ScrubPainter extends CustomPainter {
  _ScrubPainter(this.s, this.x0, this.x1, this.value, this.label);
  final double s, x0, x1, value;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2 - 0.75 * s;
    final dot = Paint()..color = DD.ink;
    void bracket(double x) {
      for (final dy in [-8.6 * s, 8.6 * s]) {
        canvas.drawRect(Rect.fromCenter(center: Offset(x, cy + dy), width: 4.3 * s, height: 4.3 * s), dot);
      }
    }

    bracket(x0);
    bracket(x1);
    final a = x0 + 1.5 * s, b = x1 - 1.5 * s;
    final tx = a + (b - a) * value.clamp(0.0, 1.0);
    canvas.drawLine(
      Offset(a, cy),
      Offset(tx, cy),
      Paint()
        ..color = DD.ink
        ..strokeWidth = 1.4 * s,
    );
    canvas.drawLine(
      Offset(tx, cy),
      Offset(b, cy),
      Paint()
        ..color = DD.line
        ..strokeWidth = 1 * s,
    );
    canvas.drawRect(Rect.fromCenter(center: Offset(tx, cy), width: 3 * s, height: 21 * s), dot);

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: DD.mono(7 * s, weight: FontWeight.w400, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x1 - 20.6 * s - tp.width, cy + 16.2 * s - tp.height / 2));
  }

  @override
  bool shouldRepaint(_ScrubPainter old) =>
      old.value != value || old.label != label || old.s != s || old.x0 != x0 || old.x1 != x1;
}
