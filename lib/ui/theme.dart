import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Design tokens taken from the reference motion piece.
abstract final class DD {
  static const bg = Color(0xFFF8F7F9);
  static const ink = Color(0xFF0B0B0C);
  static const dot = Color(0xFFBDBCC2);
  static const mute = Color(0xFF8C8B93);
  static const line = Color(0xFFD9D8DE);

  static const font = 'SpaceMono';

  /// Reference frame width the layout was measured against (iPhone 15).
  static const designWidth = 393.0;

  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = ink,
    double height = 1.25,
    double spacing = 0,
  }) => TextStyle(
    fontFamily: font,
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: spacing,
  );
}

const _days = ['MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY'];
const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

String two(int n) => n.toString().padLeft(2, '0');

String weekday(DateTime t) => _days[t.weekday - 1];
String month(DateTime t) => _months[t.month - 1];

/// `MONDAY\n01\nMAY`
String stackedDate(DateTime t) => '${weekday(t)}\n${two(t.day)}\n${month(t)}';

/// `MON 01 MAY 2026`
String longDate(DateTime t) => '${weekday(t).substring(0, 3)} ${two(t.day)} ${month(t)} ${t.year}';

/// `9:PM` on the hour, `9:41PM` otherwise — the reference's clock style.
String clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final ap = t.hour < 12 ? 'AM' : 'PM';
  return t.minute == 0 ? '$h:$ap' : '$h:${two(t.minute)}$ap';
}

String hms(DateTime t) => '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';

/// Breaks [text] into lines of at most [width] characters the way the
/// reference does (`PROJECT / ASSIGNM / ENT`): words stay together when they
/// fit, long words are cut hard.
String hardWrap(String text, int width) {
  final pieces = <String>[];
  for (final word in text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty)) {
    for (var i = 0; i < word.length; i += width) {
      pieces.add(word.substring(i, (i + width).clamp(0, word.length)));
    }
  }
  final lines = <String>[];
  var cur = '';
  for (final p in pieces) {
    if (cur.isEmpty) {
      cur = p;
    } else if (cur.length + 1 + p.length <= width) {
      cur = '$cur $p';
    } else {
      lines.add(cur);
      cur = p;
    }
  }
  if (cur.isNotEmpty) lines.add(cur);
  return lines.join('\n');
}

/// Breaks [text] regardless of words using the reference's rhythm of
/// 9, 7, then 9 characters per line (`CALCULATE / D_AZIMU / TH: 345°`).
String breakAll(String text, [List<int> widths = const [9, 7, 9]]) {
  final lines = <String>[];
  var i = 0;
  while (i < text.length) {
    final w = widths[math.min(lines.length, widths.length - 1)];
    lines.add(text.substring(i, math.min(i + w, text.length)).trimLeft());
    i += w;
  }
  return lines.join('\n');
}
