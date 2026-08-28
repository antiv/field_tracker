import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> storeFileTemporarily(Uint8List data, String name) async {
  final tempDir = await getTemporaryDirectory();

  final path = '${tempDir.path}/$name';
  final file = await File(path).create();
  file.writeAsBytesSync(data);

  return path;
}