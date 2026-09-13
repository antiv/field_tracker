import 'dart:convert';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../model/placemark.dart';
import '../model/species.dart';
import '../model/transect.dart';
import '../service/media_service.dart';
import 'kml_utils.dart';

/// KMZ is a zip holding `doc.kml` plus a `files/` folder. Photos ride along in
/// there, so a shared survey opens in Google Earth with its images intact —
/// something a bare .kml can only ever reference by name.
///
/// Like the backup archive, both directions stream to and from disk: a survey
/// can carry hundreds of photos, far more than fits in memory twice over.
class KMZUtils {
  /// Photo file names referenced by [transect] that are actually on disk.
  /// Touches the file system, so call it once per export, never from a build.
  static List<String> availablePhotos(Transect transect) {
    final names = <String>{};
    for (final marker in transect.markers ?? <Placemark>[]) {
      for (final record in marker.species ?? <Species>[]) {
        names.addAll(record.photos);
      }
    }
    return names.where(MediaService().exists).toList()..sort();
  }

  static Future<void> writeKMZ(
      Transect transect, String outPath, List<String> photos) async {
    final encoder = ZipFileEncoder();
    encoder.create(outPath);
    try {
      encoder.addArchiveFile(ArchiveFile.string(
          kKmzDocName, KMLUtils.generateKML(transect, photos: photos)));
      for (final name in photos) {
        await encoder.addFile(
            MediaService().fileFor(name), '$kKmzFilesDir/$name');
      }
    } finally {
      await encoder.close();
    }
  }

  /// Unpacks a KMZ: photos land in the media directory under their original
  /// names, so the names already carried in ExtendedData keep resolving.
  static Future<Transect> readKMZ(String archivePath, DateTime fileDate) async {
    await MediaService().init();
    final input = InputFileStream(archivePath);
    String? kml;
    try {
      for (final entry in ZipDecoder().decodeStream(input)) {
        if (!entry.isFile) continue;
        if (p.extension(entry.name).toLowerCase() == '.kml') {
          /// doc.kml is the convention, but the spec only requires the first
          /// .kml in the archive to be the document
          kml ??=
              utf8.decode(entry.readBytes() ?? const [], allowMalformed: true);
        } else if (p.dirname(entry.name) == kKmzFilesDir) {
          final out = OutputFileStream(
              MediaService().fileFor(p.basename(entry.name)).path);
          entry.writeContent(out);
          await out.close();
        }
      }
    } finally {
      await input.close();
    }

    if (kml == null) {
      throw const FormatException('KMZ contains no KML document');
    }
    return KMLUtils().kmlToTransect(kml, fileDate);
  }
}
