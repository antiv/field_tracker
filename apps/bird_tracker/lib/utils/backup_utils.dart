import 'dart:convert';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../service/media_service.dart';

/// Base name of the backup archive and of the records file inside it.
const String kBackupBaseName = 'bird_tracker_backup';
const String kBackupJsonName = '$kBackupBaseName.json';

/// Folder inside the backup archive holding the record photos.
const String kBackupMediaDir = 'media';

/// A backup is a zip holding the records JSON — byte-identical to the old
/// plain-JSON backup — plus the photos those records name. Without the photos
/// a restore on another device would rebuild every record around a file name
/// that resolves to nothing.
///
/// Both directions stream through the file system rather than building the
/// archive in memory: a season's worth of field photos is hundreds of
/// megabytes, and buffering that would take the app down on a phone.
class BackupUtils {
  static Future<void> write(
      String outPath, String jsonString, Iterable<String> photoNames) async {
    final encoder = ZipFileEncoder();
    encoder.create(outPath);
    try {
      encoder.addArchiveFile(ArchiveFile.string(kBackupJsonName, jsonString));
      for (final name in photoNames.toSet()) {
        if (!MediaService().exists(name)) continue;
        await encoder.addFile(
            MediaService().fileFor(name), '$kBackupMediaDir/$name');
      }
    } finally {
      await encoder.close();
    }
  }

  /// Unpacks the archive: photos land in the media directory under the names
  /// the records already reference, and the records JSON comes back.
  static Future<String> read(String archivePath) async {
    await MediaService().init();
    final input = InputFileStream(archivePath);
    String? json;
    try {
      for (final entry in ZipDecoder().decodeStream(input)) {
        if (!entry.isFile) continue;
        if (p.dirname(entry.name) == '.' &&
            p.basename(entry.name) == kBackupJsonName) {
          json =
              utf8.decode(entry.readBytes() ?? const [], allowMalformed: true);
        } else if (p.dirname(entry.name) == kBackupMediaDir) {
          final out = OutputFileStream(
              MediaService().fileFor(p.basename(entry.name)).path);
          entry.writeContent(out);
          await out.close();
        }
      }
    } finally {
      await input.close();
    }
    if (json == null) {
      throw const FormatException('Backup archive has no $kBackupJsonName');
    }
    return json;
  }
}
