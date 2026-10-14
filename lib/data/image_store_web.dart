import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

Future<void> init() async {}

Future<String> save(String id, List<int> bytes) async => 'b64:${base64Encode(bytes)}';

Future<void> delete(String ref) async {}

ImageProvider? provider(String ref) {
  if (!ref.startsWith('b64:')) return null;
  return MemoryImage(Uint8List.fromList(base64Decode(ref.substring(4))));
}
