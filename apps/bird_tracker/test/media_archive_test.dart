import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:bird_tracker/model/placemark.dart';
import 'package:bird_tracker/model/point.dart';
import 'package:bird_tracker/model/species.dart';
import 'package:bird_tracker/model/transect.dart';
import 'package:bird_tracker/service/media_service.dart';
import 'package:bird_tracker/utils/backup_utils.dart';
import 'package:bird_tracker/utils/file_utils.dart';
import 'package:bird_tracker/utils/kml_utils.dart';
import 'package:bird_tracker/utils/kmz_utils.dart';
import 'package:flutter_test/flutter_test.dart';

const String photoA = 'BT_20260504_211530_0a1b.jpg';
const String photoB = 'BT_20260504_214000_0c2d.jpg';

/// A 1×1 GIF is the smallest thing that is unambiguously binary — enough to
/// prove the bytes survive a zip round trip.
final List<int> pixel = base64Decode('R0lGODlhAQABAAAAACw=');

Transect buildTransect() {
  final first = Species()
    ..species = 'Parus major'
    ..time = '21:15:30'
    ..count = 3
    ..code = 12
    ..stratification = Stratification.g
    ..direction = Direction.nne
    ..description = 'pevanje'
    ..photos = [photoA, photoB];

  final second = Species()
    ..species = 'Sitta europaea'
    ..time = '21:40:00'
    ..count = 1
    ..code = null
    ..description = null;

  return Transect()
    ..id = 1
    ..name = 'Test transekt'
    ..startDate = DateTime(2026, 5, 4, 20)
    ..endDate = DateTime(2026, 5, 4, 22)
    ..points = [
      Point()
        ..latitude = 44.8
        ..longitude = 20.36
    ]
    ..markers = [
      Placemark(
        id: 0,
        startDate: DateTime(2026, 5, 4, 21, 15),
        endDate: DateTime(2026, 5, 4, 21, 45),
        latitude: 44.812345,
        longitude: 20.361234,
        species: [first, second],
      )
    ];
}

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('bird_media_test');
    await MediaService().init(root: root.path);
    for (final name in [photoA, photoB]) {
      await MediaService().fileFor(name).writeAsBytes(pixel, flush: true);
    }
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  String outPath(String name) => '${root.path}/$name';

  Map<String, ArchiveFile> entriesOf(String path) => {
        for (final f in ZipDecoder().decodeStream(InputFileStream(path)))
          if (f.isFile) f.name: f
      };

  test('KMZ embeds the record photos and survives a round trip', () async {
    final transect = buildTransect();
    expect(transect.hasPhotos, isTrue);

    final available = KMZUtils.availablePhotos(transect);
    expect(available, [photoA, photoB]);

    final kmz = outPath('survey.kmz');
    await KMZUtils.writeKMZ(transect, kmz, available);

    final entries = entriesOf(kmz);
    expect(entries.keys.toSet(),
        {kKmzDocName, '$kKmzFilesDir/$photoA', '$kKmzFilesDir/$photoB'});
    expect(entries['$kKmzFilesDir/$photoA']!.content, pixel);

    /// the balloon must reference the bundled copies, not absolute paths
    final doc = utf8.decode(entries[kKmzDocName]!.content as List<int>);
    expect(doc, contains('<img src="$kKmzFilesDir/$photoA" width="400"/>'));

    /// unpacking into an empty store must put the files back under the very
    /// names the records carry
    await MediaService().delete([photoA, photoB]);
    expect(MediaService().exists(photoA), isFalse);

    final restored = await KMZUtils.readKMZ(kmz, DateTime(2026, 5, 4));
    final back = restored.markers!.single.species!;
    expect(back.first.photos, [photoA, photoB]);
    expect(back.last.photos, isEmpty);
    expect(MediaService().exists(photoA), isTrue);
    expect(MediaService().fileFor(photoB).readAsBytesSync(), pixel);
  });

  test('a transect with no photos still exports as plain KML', () {
    final transect = buildTransect();
    for (final record in transect.markers!.single.species!) {
      record.photos = [];
    }
    expect(transect.hasPhotos, isFalse);
    expect(transect.toKML(), contains('Parus major'));
  });

  test('hasPhotos never touches the disk, availablePhotos does', () async {
    /// the history list calls hasPhotos from its item builder, so it must
    /// stay true for a record whose file has gone missing — only the export
    /// is allowed to pay for a stat
    await MediaService().delete([photoA, photoB]);

    final transect = buildTransect();
    expect(transect.hasPhotos, isTrue);
    expect(KMZUtils.availablePhotos(transect), isEmpty);
  });

  test('a photo left out of the bundle is left out of the balloon', () async {
    await MediaService().delete([photoB]);

    final transect = buildTransect();
    final available = KMZUtils.availablePhotos(transect);
    expect(available, [photoA]);

    final kmz = outPath('partial.kmz');
    await KMZUtils.writeKMZ(transect, kmz, available);

    final doc = utf8.decode(entriesOf(kmz)[kKmzDocName]!.content as List<int>);
    expect(doc, contains('<img src="$kKmzFilesDir/$photoA" width="400"/>'));
    expect(doc, isNot(contains('<img src="$kKmzFilesDir/$photoB"')));

    /// the name still travels in ExtendedData though — dropping it would
    /// silently lose the record's own history of what was photographed
    expect(doc, contains(photoB));
  });

  test('backup archive carries the records JSON and the photos', () async {
    final json = jsonEncode([buildTransect().toJson()]);
    final backup = outPath('$kBackupBaseName.zip');
    await BackupUtils.write(backup, json, [photoA, photoB, 'missing.jpg']);

    final entries = entriesOf(backup);
    expect(entries.keys.toSet(), {
      kBackupJsonName,
      '$kBackupMediaDir/$photoA',
      '$kBackupMediaDir/$photoB',
    });

    await MediaService().delete([photoA, photoB]);
    expect(await BackupUtils.read(backup), json);
    expect(MediaService().exists(photoA), isTrue);
    expect(MediaService().fileFor(photoB).readAsBytesSync(), pixel);
  });

  test('an export survives a transect name with a path separator in it', () {
    /// the name is free text; a slash used to become a directory in the
    /// shared file's path and take the extension with it
    expect(sanitizeFileName('Bara 1/2 "kod mosta"'), 'Bara 1_2 _kod mosta_');
    expect(sanitizeFileName('  '), 'transect');
    expect(sanitizeFileName('30/08/2026'), '30_08_2026');
  });

  test('a KMZ is recognised by its bytes, not by its name', () async {
    final transect = buildTransect();

    /// exactly what a mail client did to a shared export: dropped the
    /// extension and left slashes in the name
    final misnamed = outPath('Transect 30.08.2026 as KMZ');
    await KMZUtils.writeKMZ(
        transect, misnamed, KMZUtils.availablePhotos(transect));

    final head = File(misnamed).openSync();
    final magic = head.readSync(4);
    head.closeSync();
    expect(magic, [0x50, 0x4B, 0x03, 0x04]);

    /// and it still imports, because the reader never looks at the name
    final imported = await KMZUtils.readKMZ(misnamed, DateTime(2026, 5, 4));
    expect(imported.markers!.single.species!.first.species, 'Parus major');
  });

  test('both export formats import back to the same records', () async {
    final transect = buildTransect();

    /// what the KML branch of the import dialog does
    final kmlPath = outPath('survey.kml');
    File(kmlPath).writeAsStringSync(transect.toKML());
    final fromKml = KMLUtils()
        .kmlToTransect(File(kmlPath).readAsStringSync(), DateTime(2026, 5, 4));

    /// and what the KMZ branch does
    final kmzPath = outPath('survey.kmz');
    await KMZUtils.writeKMZ(
        transect, kmzPath, KMZUtils.availablePhotos(transect));
    final fromKmz = await KMZUtils.readKMZ(kmzPath, DateTime(2026, 5, 4));

    for (final imported in [fromKml, fromKmz]) {
      final marker = imported.markers!.single;
      expect(marker.latitude, closeTo(44.812345, 0.000001));
      expect(marker.longitude, closeTo(20.361234, 0.000001));
      expect(marker.species!.length, 2);

      final record = marker.species!.first;
      expect(record.species, 'Parus major');
      expect(record.count, 3);
      expect(record.code, 12);
      expect(record.stratification, Stratification.g);
      expect(record.direction, Direction.nne);

      /// the names travel in both; only the KMZ carries the files
      expect(record.photos, [photoA, photoB]);
    }

    /// a KMZ that lost its photos on the way is still a valid import — the
    /// record keeps the names, which is what a plain KML would have given
    await MediaService().delete([photoA, photoB]);
    final bare = outPath('bare.kmz');
    await KMZUtils.writeKMZ(transect, bare, const []);
    final fromBare = await KMZUtils.readKMZ(bare, DateTime(2026, 5, 4));
    expect(fromBare.markers!.single.species!.first.photos, [photoA, photoB]);
    expect(MediaService().exists(photoA), isFalse);
  });

  test('photoNames gathers every photo the delete dialog has to warn about',
      () {
    final transect = buildTransect();
    expect(transect.photoNames, [photoA, photoB]);
    expect(transect.markers!.single.photoNames, [photoA, photoB]);

    for (final record in transect.markers!.single.species!) {
      record.photos = [];
    }
    expect(transect.photoNames, isEmpty);
  });

  test('a legacy record without a photos key restores as an empty list', () {
    final legacy = Species()
      ..species = 'Parus major'
      ..time = '21:15:30'
      ..count = 1
      ..code = null
      ..description = null;
    final json = legacy.toJson()..remove('photos');

    expect(Species.fromJson(json).photos, isEmpty);
  });
}
