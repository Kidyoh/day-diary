import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/entry.dart';
import '../../data/image_store.dart';
import '../theme.dart';
import 'dot_matrix.dart';

/// The photo of an entry, or a dot-matrix time card for text-only entries.
class EntryImage extends StatelessWidget {
  const EntryImage({super.key, required this.entry, this.scale = 1});

  final DiaryEntry entry;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final provider = ImageStore.provider(entry.image);
    if (provider == null) {
      return ColoredBox(
        color: const Color(0xFFD6D4D0),
        child: Center(
          child: FractionallySizedBox(
            widthFactor: 0.62,
            child: FittedBox(child: DotMatrixText(clock(entry.createdAt), pitch: 4, color: DD.ink)),
          ),
        ),
      );
    }
    return Image(
      image: provider,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFD6D4D0)),
    );
  }
}

/// Average brightness (0..1) of the top and lower bands of an entry photo,
/// used to pick black or white overlay text in the detail view.
class Luma {
  static final Map<String, ({double top, double bottom})> _cache = {};

  static ({double top, double bottom})? cached(DiaryEntry e) => _cache[e.id];

  static Future<({double top, double bottom})> of(DiaryEntry e) async {
    final hit = _cache[e.id];
    if (hit != null) return hit;
    final provider = ImageStore.provider(e.image);
    if (provider == null) return _cache[e.id] = (top: 0.8, bottom: 0.8);
    try {
      final image = await _decode(ResizeImage(provider, width: 12, height: 22, policy: ResizeImagePolicy.exact));
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return (top: 0.8, bottom: 0.4);
      double band(int y0, int y1) {
        var sum = 0.0, n = 0;
        for (var y = y0; y < y1; y++) {
          for (var x = 0; x < 12; x++) {
            final i = (y * 12 + x) * 4;
            sum += (0.2126 * data.getUint8(i) + 0.7152 * data.getUint8(i + 1) + 0.0722 * data.getUint8(i + 2)) / 255;
            n++;
          }
        }
        return sum / n;
      }

      return _cache[e.id] = (top: band(0, 6), bottom: band(12, 18));
    } catch (_) {
      return (top: 0.8, bottom: 0.4);
    }
  }

  static Future<ui.Image> _decode(ImageProvider provider) {
    final done = Completer<ui.Image>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!done.isCompleted) done.complete(info.image);
      },
      onError: (Object e, StackTrace? st) {
        stream.removeListener(listener);
        if (!done.isCompleted) done.completeError(e, st);
      },
    );
    stream.addListener(listener);
    return done.future;
  }
}
