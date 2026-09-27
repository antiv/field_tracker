import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// A transect name is free text, and it lands in the name of every exported
/// file. A `/` in it used to become a directory separator in the shared file's
/// path, taking the extension with it and leaving the import unable to tell a
/// KMZ from a KML.
String sanitizeFileName(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
      .trim();
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

/// Packs [paths] into a zip at [outPath], each file at the archive root under
/// its own name. Streams from disk: a batch of KMZs can be large.
Future<void> zipFiles(Iterable<String> paths, String outPath) async {
  final encoder = ZipFileEncoder();
  encoder.create(outPath);
  try {
    for (final path in paths) {
      await encoder.addFile(File(path), p.basename(path));
    }
  } finally {
    await encoder.close();
  }
}
