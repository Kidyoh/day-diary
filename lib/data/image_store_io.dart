import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

const _folder = 'entries';

String? _docs;

Future<void> init() async {
  _docs = (await getApplicationDocumentsDirectory()).path;
  await Directory('$_docs/$_folder').create(recursive: true);
}

Future<String> save(String id, List<int> bytes) async {
  // Store a path relative to the documents directory: on iOS the absolute
  // container path changes between installs and updates.
  final rel = '$_folder/$id.jpg';
  await File('$_docs/$rel').writeAsBytes(bytes, flush: true);
  return 'doc:$rel';
}

Future<void> delete(String ref) async {
  if (!ref.startsWith('doc:') || _docs == null) return;
  final file = File('$_docs/${ref.substring(4)}');
  if (await file.exists()) await file.delete();
}

ImageProvider? provider(String ref) {
  if (!ref.startsWith('doc:') || _docs == null) return null;
  return FileImage(File('$_docs/${ref.substring(4)}'));
}
