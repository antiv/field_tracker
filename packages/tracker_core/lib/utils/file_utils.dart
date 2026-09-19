import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// A transect name is free text, and it lands in the name of every exported
/// file. A `/` in it used to become a directory separator in the shared file's
/// path, taking the extension with it and leaving the import unable to tell a
/// KMZ from a KML.
String sanitizeFileName(String value) {
  final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
  return cleaned.isEmpty ? 'transect' : cleaned;
}

Future<String> temporaryFilePath(String name) async {
  final tempDir = await getTemporaryDirectory();
  return '${tempDir.path}/$name';
}

Future<String> storeFileTemporarily(Uint8List data, String name) async {
  final path = await temporaryFilePath(name);
  final file = await File(path).create();
  file.writeAsBytesSync(data);

  return path;
}
