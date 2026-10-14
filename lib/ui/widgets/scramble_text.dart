import 'dart:math' as math;

import 'package:flutter/material.dart';

const _noise = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_#/:+-';

int _rand(int a, int b) {
  final v = math.sin(a * 91.3458 + b * 47.123) * 24634.6345;
  return ((v - v.floorToDouble()) * 1e6).floor();
}

/// Decodes [text] in character by character, each one cycling through random
/// glyphs before it settles (the reference's `CALCULATED_AZIMUTH` headline).
/// [progress] is driven from outside, 0 → nothing, 1 → final text.
class ScrambleText extends StatelessWidget {
  const ScrambleText(this.text, {super.key, required this.progress, required this.style, this.window = 0.3});

  final String text;
  final double progress;
  final TextStyle style;
  final double window;

  @override
  Widget build(BuildContext context) {
    if (progress >= 1) return Text(text, style: style, softWrap: false);
    final frame = (progress * 60).floor();
    final out = StringBuffer();
    final n = math.max(1, text.length);
    for (var i = 0; i < text.length; i++) {
      final ch = text[i];
      if (ch == '\n' || ch == ' ') {
        out.write(ch);
        continue;
      }
      final start = i / n * (1 - window);
      final local = (progress - start) / window;
      if (local <= 0) {
        out.write(' ');
      } else if (local < 1) {
        out.write(_noise[_rand(i, frame) % _noise.length]);
      } else {
        out.write(ch);
      }
    }
    return Text(out.toString(), style: style, softWrap: false);
  }
}

/// Re-scrambles itself whenever [text] changes (timeline labels).
class SwapScrambleText extends StatefulWidget {
  const SwapScrambleText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<SwapScrambleText> createState() => _SwapScrambleTextState();
}

class _SwapScrambleTextState extends State<SwapScrambleText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );

  @override
  void didUpdateWidget(SwapScrambleText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, _) =>
        ScrambleText(widget.text, progress: Curves.easeOut.transform(_c.value), style: widget.style, window: 0.45),
  );
}

/// Types [text] out with a blinking block cursor.
class TypeText extends StatelessWidget {
  const TypeText(
    this.text, {
    super.key,
    required this.progress,
    required this.style,
    this.cursor = true,
    this.blink = 0,
  });

  final String text;
  final double progress;
  final TextStyle style;
  final bool cursor;

  /// 0..1 phase of the cursor blink.
  final double blink;

  @override
  Widget build(BuildContext context) {
    final count = (text.length * progress.clamp(0.0, 1.0)).round();
    final shown = text.substring(0, count);
    final showCursor = cursor && progress > 0 && (progress < 1 || blink < 0.5);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: shown),
          TextSpan(
            text: '_',
            style: TextStyle(color: showCursor ? style.color : style.color?.withValues(alpha: 0)),
          ),
        ],
      ),
      style: style,
    );
  }
}
