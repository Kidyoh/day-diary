import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// 5×7 dot-matrix glyphs (narrow glyphs use fewer columns).
const Map<String, List<String>> _glyphs = {
  '0': ['.###.', '#...#', '#..##', '#.#.#', '##..#', '#...#', '.###.'],
  '1': ['..#..', '.##..', '..#..', '..#..', '..#..', '..#..', '.###.'],
  '2': ['.###.', '#...#', '....#', '...#.', '..#..', '.#...', '#####'],
  '3': ['#####', '...#.', '..#..', '...#.', '....#', '#...#', '.###.'],
  '4': ['...#.', '..##.', '.#.#.', '#..#.', '#####', '...#.', '...#.'],
  '5': ['#####', '#....', '####.', '....#', '....#', '#...#', '.###.'],
  '6': ['..##.', '.#...', '#....', '####.', '#...#', '#...#', '.###.'],
  '7': ['#####', '....#', '...#.', '..#..', '.#...', '.#...', '.#...'],
  '8': ['.###.', '#...#', '#...#', '.###.', '#...#', '#...#', '.###.'],
  '9': ['.###.', '#...#', '#...#', '.####', '....#', '...#.', '.##..'],
  'A': ['.###.', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
  'B': ['####.', '#...#', '#...#', '####.', '#...#', '#...#', '####.'],
  'C': ['.###.', '#...#', '#....', '#....', '#....', '#...#', '.###.'],
  'D': ['###..', '#..#.', '#...#', '#...#', '#...#', '#..#.', '###..'],
  'E': ['#####', '#....', '#....', '####.', '#....', '#....', '#####'],
  'F': ['#####', '#....', '#....', '####.', '#....', '#....', '#....'],
  'G': ['.###.', '#...#', '#....', '#.###', '#...#', '#...#', '.####'],
  'H': ['#...#', '#...#', '#...#', '#####', '#...#', '#...#', '#...#'],
  'I': ['.###.', '..#..', '..#..', '..#..', '..#..', '..#..', '.###.'],
  'J': ['..###', '...#.', '...#.', '...#.', '...#.', '#..#.', '.##..'],
  'K': ['#...#', '#..#.', '#.#..', '##...', '#.#..', '#..#.', '#...#'],
  'L': ['#....', '#....', '#....', '#....', '#....', '#....', '#####'],
  'M': ['#...#', '##.##', '#.#.#', '#.#.#', '#...#', '#...#', '#...#'],
  'N': ['#...#', '#...#', '##..#', '#.#.#', '#..##', '#...#', '#...#'],
  'O': ['.###.', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
  'P': ['####.', '#...#', '#...#', '####.', '#....', '#....', '#....'],
  'Q': ['.###.', '#...#', '#...#', '#...#', '#.#.#', '#..#.', '.##.#'],
  'R': ['####.', '#...#', '#...#', '####.', '#.#..', '#..#.', '#...#'],
  'S': ['.####', '#....', '#....', '.###.', '....#', '....#', '####.'],
  'T': ['#####', '..#..', '..#..', '..#..', '..#..', '..#..', '..#..'],
  'U': ['#...#', '#...#', '#...#', '#...#', '#...#', '#...#', '.###.'],
  'V': ['#...#', '#...#', '#...#', '#...#', '#...#', '.#.#.', '..#..'],
  'W': ['#...#', '#...#', '#...#', '#.#.#', '#.#.#', '#.#.#', '.#.#.'],
  'X': ['#...#', '#...#', '.#.#.', '..#..', '.#.#.', '#...#', '#...#'],
  'Y': ['#...#', '#...#', '.#.#.', '..#..', '..#..', '..#..', '..#..'],
  'Z': ['#####', '....#', '...#.', '..#..', '.#...', '#....', '#####'],
  ':': ['.', '.', '#', '.', '.', '#', '.'],
  '.': ['.', '.', '.', '.', '.', '.', '#'],
  '+': ['.....', '..#..', '..#..', '#####', '..#..', '..#..', '.....'],
  '-': ['.....', '.....', '.....', '#####', '.....', '.....', '.....'],
  '_': ['.....', '.....', '.....', '.....', '.....', '.....', '#####'],
  '/': ['....#', '...#.', '...#.', '..#..', '.#...', '.#...', '#....'],
  '°': ['.#.', '#.#', '.#.', '...', '...', '...', '...'],
  ' ': ['...', '...', '...', '...', '...', '...', '...'],
};

List<String> _glyph(String c) => _glyphs[c.toUpperCase()] ?? _glyphs[' ']!;

/// Lays [text] out on a dot grid. Returns the "on" cells and grid width.
({Set<int> on, int cols}) _cells(String text) {
  final on = <int>{};
  var x = 0;
  for (var i = 0; i < text.length; i++) {
    final g = _glyph(text[i]);
    for (var r = 0; r < 7; r++) {
      for (var c = 0; c < g[r].length; c++) {
        if (g[r][c] == '#') on.add((x + c) * 8 + r);
      }
    }
    x += g[0].length + (i == text.length - 1 ? 0 : 1);
  }
  return (on: on, cols: x);
}

int dotColumns(String text) => _cells(text).cols;

/// Dot-matrix text (the reference's `9:PM` and `+80`). When [text] changes
/// the dots dissolve from the old string into the new one.
class DotMatrixText extends StatefulWidget {
  const DotMatrixText(
    this.text, {
    super.key,
    required this.pitch,
    this.color = const Color(0xFF0B0B0C),
    this.outline,
    this.maxWidth,
    this.dotFraction = 0.74,
    this.reveal = 1,
  });

  final String text;

  /// Distance between dot centres.
  final double pitch;
  final Color color;

  /// Optional thin outline around every dot (keeps white dots readable on
  /// bright photos).
  final Color? outline;

  /// Shrinks the pitch so the text never grows wider than this.
  final double? maxWidth;
  final double dotFraction;

  /// 0..1 — externally driven reveal; dots flicker on at random moments.
  final double reveal;

  @override
  State<DotMatrixText> createState() => _DotMatrixTextState();
}

class _DotMatrixTextState extends State<DotMatrixText> with SingleTickerProviderStateMixin {
  late final AnimationController _swap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
    value: 1,
  );
  String _from = '';

  @override
  void didUpdateWidget(DotMatrixText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _from = old.text;
      _swap.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _swap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cols = math.max(dotColumns(widget.text), dotColumns(_from));
    var pitch = widget.pitch;
    if (widget.maxWidth != null && cols * pitch > widget.maxWidth!) {
      pitch = widget.maxWidth! / cols;
    }
    return AnimatedBuilder(
      animation: _swap,
      builder: (context, _) => CustomPaint(
        size: Size(dotColumns(widget.text) * pitch, 7 * pitch),
        painter: _DotPainter(
          from: _from,
          to: widget.text,
          t: _swap.value,
          reveal: widget.reveal,
          pitch: pitch,
          color: widget.color,
          outline: widget.outline,
          dotFraction: widget.dotFraction,
        ),
      ),
    );
  }
}

double _hash(int a, int b) {
  final v = math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
  return v - v.floorToDouble();
}

class _DotPainter extends CustomPainter {
  _DotPainter({
    required this.from,
    required this.to,
    required this.t,
    required this.reveal,
    required this.pitch,
    required this.color,
    required this.outline,
    required this.dotFraction,
  });

  final String from, to;
  final double t, reveal, pitch, dotFraction;
  final Color color;
  final Color? outline;

  @override
  void paint(Canvas canvas, Size size) {
    final a = _cells(from).on;
    final b = _cells(to).on;
    final cols = math.max(_cells(from).cols, _cells(to).cols);
    final fill = Paint()..color = color;
    final stroke = outline == null
        ? null
        : (Paint()
            ..color = outline!
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(0.6, pitch * 0.08));
    final side = pitch * dotFraction;
    final radius = Radius.circular(side * 0.12);
    final flickerFrame = (t * 14).floor() + (reveal * 14).floor() * 7;

    for (var x = 0; x < cols; x++) {
      for (var r = 0; r < 7; r++) {
        final key = x * 8 + r;
        final th = _hash(x, r);
        // Swap dissolve between the old and new string.
        var lit = t >= th ? b.contains(key) : a.contains(key);
        if (t < 1 && (t - th).abs() < 0.12) {
          lit = _hash(key, flickerFrame) > 0.55;
        }
        // External reveal with a flicker window before each dot settles.
        if (reveal <= 0) {
          lit = false;
        } else if (reveal < 1) {
          final rt = th * 0.8;
          if (reveal < rt - 0.15) {
            lit = false;
          } else if (reveal < rt) {
            lit = _hash(key, flickerFrame) > 0.5;
          }
        }
        if (!lit) continue;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x * pitch + (pitch - side) / 2, r * pitch + (pitch - side) / 2, side, side),
          radius,
        );
        canvas.drawRRect(rect, fill);
        if (stroke != null) canvas.drawRRect(rect, stroke);
      }
    }
  }

  @override
  bool shouldRepaint(_DotPainter old) =>
      old.t != t ||
      old.reveal != reveal ||
      old.to != to ||
      old.from != from ||
      old.pitch != pitch ||
      old.color != color;
}
