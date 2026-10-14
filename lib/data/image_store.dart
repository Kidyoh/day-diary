import 'package:flutter/widgets.dart';

import 'image_store_stub.dart'
    if (dart.library.io) 'image_store_io.dart'
    if (dart.library.js_interop) 'image_store_web.dart'
    as platform;

/// Stores entry photos and turns stored references back into images.
///
/// References are plain strings so they can live in the JSON entry list:
/// * `asset:<path>` — bundled sample photos
/// * `doc:<relative path>` — files in the app documents directory (mobile)
/// * `b64:<data>` — inline bytes (web, where there is no file system)
class ImageStore {
  ImageStore._();

  static final Map<String, ImageProvider> _cache = {};

  static Future<void> init() => platform.init();

  static Future<String> save(String id, List<int> bytes) => platform.save(id, bytes);

  static Future<void> delete(String ref) async {
    _cache.remove(ref);
    if (ref.startsWith('asset:')) return;
    await platform.delete(ref);
  }

  static ImageProvider? provider(String? ref) {
    if (ref == null || ref.isEmpty) return null;
    return _cache.putIfAbsent(ref, () {
      if (ref.startsWith('asset:')) return AssetImage(ref.substring(6));
      return platform.provider(ref) ?? const AssetImage('');
    });
  }
}
