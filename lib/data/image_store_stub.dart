import 'package:flutter/widgets.dart';

Future<void> init() async {}

Future<String> save(String id, List<int> bytes) => throw UnsupportedError('No image storage on this platform');

Future<void> delete(String ref) async {}

ImageProvider? provider(String ref) => null;
