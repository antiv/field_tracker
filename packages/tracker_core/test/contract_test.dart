import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracker_core/app/merged_asset_loader.dart';
import 'package:tracker_core/testing.dart';
import 'package:tracker_core/tracker_core.dart';
import 'package:xml/xml.dart';

import 'test_config.dart';

Transect buildTransect({List<TrackerRecord>? records}) => Transect()
  ..id = 1
  ..name = 'Test, transekt'
  ..startDate = DateTime(2026, 5, 4, 20)
  ..endDate = DateTime(2026, 5, 4, 22)
  ..points = []
  ..markers = [
    Placemark(
      id: 0,
      startDate: DateTime(2026, 5, 4, 21, 15),
      latitude: 44.812345,
      longitude: 20.361234,
      altitude: 117.4,
      accuracy: 4.8,
      records:
          records ??
          [
            TestRecord(
              species: 'Parus major',
              note: 'uz put, "kod mosta"',
              photos: ['a.jpg', 'b, c.jpg'],
            ),
            TestRecord(species: 'Sitta europaea'),
          ],
    ),
  ];

String payloadKml(String prefix, String namespace) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:$prefix="$namespace">
<Document><name>Tuđi izvoz</name>
<Placemark id="marker0"><name>Point 1</name>
<ExtendedData><$prefix:records>${jsonEncode({
      'startDate': '2026-05-04T21:15:00.000',
      'altitude': 117.4,
      'species': [
        {'species': 'Bufo bufo', 'note': 'iz drugog trackera', 'photos': []},
      ],
    })}</$prefix:records></ExtendedData>
<Point><coordinates>20.361234,44.812345</coordinates></Point>
</Placemark></Document></kml>''';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TrackerConfig.current = testConfig();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('KML', () {
    test('the payload is read whatever namespace another app wrote it in', () {
      /// bird_tracker writes bt:, herp_tracker herp: — a survey exported by
      /// one is still a survey to the other
      for (final (prefix, ns) in [
        ('bt', 'https://antonijevic.rs/bird_tracker'),
        ('herp', 'https://antonijevic.rs/herp_tracker'),
      ]) {
        final imported = KMLUtils().kmlToTransect(
          payloadKml(prefix, ns),
          DateTime(2026, 8, 30),
        );
        final marker = imported.markers!.single;
        expect(marker.startDate, DateTime(2026, 5, 4, 21, 15));
        expect(marker.altitude, 117.4);
        expect(marker.records!.single.species, 'Bufo bufo', reason: prefix);
      }
    });

    test('the pre-namespace plain <Data name="records"> still imports', () {
      final kml =
          '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"><Document><name>Stari</name>
<Placemark><name>Point 1</name><ExtendedData><Data name="records"><value>${jsonEncode({
            'species': [
              {'species': 'Parus major', 'note': null, 'photos': []},
            ],
          })}</value></Data></ExtendedData>
<Point><coordinates>20.36,44.81</coordinates></Point></Placemark>
</Document></kml>''';
      final imported = KMLUtils().kmlToTransect(kml, DateTime(2026, 8, 30));
      expect(imported.markers!.single.records!.single.species, 'Parus major');
    });

    test('a placemark with no payload yields no records unless the app parses '
        'descriptions', () {
      const kml = '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2"><Document><name>Tuđi</name>
<Placemark><name>P</name><description>Parus major: 3</description>
<Point><coordinates>20.36,44.81</coordinates></Point></Placemark>
</Document></kml>''';
      final imported = KMLUtils().kmlToTransect(kml, DateTime(2026, 8, 30));
      expect(imported.markers!.single.records, isEmpty);
    });

    test('altitude and accuracy round-trip through the payload', () {
      final restored = KMLUtils().kmlToTransect(
        buildTransect().toKML(),
        DateTime(2026, 5, 4),
      );
      expect(restored.markers!.single.altitude, 117.4);
      expect(restored.markers!.single.accuracy, 4.8);
    });

    test('the balloon lists every column of every record, numbered', () {
      final kml = buildTransect().toKML();
      final placemark = XmlDocument.parse(
        kml,
      ).findAllElements('Placemark').first;
      final rows = {
        for (final data in placemark.findAllElements('Data'))
          data.getAttribute('name')!: data
              .findElements('value')
              .first
              .innerText,
      };
      expect(rows['1. Species'], 'Parus major');
      expect(rows['1. Note'], 'uz put, "kod mosta"');
      expect(rows['1. csv_header.photos'], 'a.jpg; b, c.jpg');
      expect(rows['2. Species'], 'Sitta europaea');
      expect(rows['2. Note'], '');
      expect(rows.length, 3 * 2);

      /// a single record needs no numbering
      final one = buildTransect(
        records: [TestRecord(species: 'Bufo bufo')],
      ).toKML();
      expect(one, contains('<Data name="Species">'));
    });
  });

  group('CSV', () {
    test('app columns first, then transect, point and photos; RFC 4180', () {
      final lines = const LineSplitter().convert(buildTransect().toCSV());
      expect(
        lines.first,
        'Species,Note,csv_header.transect,csv_header.point,csv_header.photos',
      );
      expect(
        lines[1],
        'Parus major,"uz put, ""kod mosta""","Test, transekt",1,"a.jpg; b, c.jpg"',
      );
      expect(lines[2], 'Sitta europaea,,"Test, transekt",1,');
    });
  });

  group('translations', () {
    test('the app file wins on a shared key and adds to nested blocks', () {
      final merged = MergedAssetLoader.merge(
        {
          'save': 'Save',
          'species_title': 'Records',
          'species': {'Parus major': 'Great Tit'},
        },
        {
          'species_title': 'Species',
          'species': {'Sitta europaea': 'Nuthatch'},
        },
      );
      expect(merged['save'], 'Save');
      expect(merged['species_title'], 'Species');
      expect(merged['species'], {
        'Parus major': 'Great Tit',
        'Sitta europaea': 'Nuthatch',
      });
    });

    testWidgets('core strings load and take the app name', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(localizedTestApp());
        await tester.pump();
      });
      await tester.pumpAndSettle();
      expect('save'.tr(), 'Save');
      expect('backup_text'.tr(namedArgs: appArgs), 'Test Tracker Backup');
      expect(
        'no_points_save_prompt'.tr(),
        'No points have been recorded. Do you want to save the transect?',
      );
      expect(
        'delete_transect_confirm'.tr(),
        'Are you sure you want to delete this transect?',
      );
      expect(
        'delete_point_confirm'.tr(),
        'Are you sure you want to delete this point?',
      );
      expect(
        'delete_record_confirm'.tr(),
        'Are you sure you want to delete this record?',
      );
      expect('transect_deleted'.tr(), 'Transect deleted');
      expect('delete'.tr(), 'Delete');
      expect('transect'.tr(), 'Transect');
      expect('about'.tr(), 'About');
    });

    testWidgets('core strings load in Serbian', (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          localizedTestApp(startLocale: const Locale('sr', 'Latn')),
        );
        await tester.pump();
      });
      await tester.pumpAndSettle();
      expect('save'.tr(), 'Sačuvaj');
      expect(
        'backup_text'.tr(namedArgs: appArgs),
        'Test Tracker rezervna kopija',
      );
      expect(
        'no_points_save_prompt'.tr(),
        'Nema zabeleženih tačaka. Da li želite da sačuvate transekt?',
      );
      expect(
        'delete_transect_confirm'.tr(),
        'Da li ste sigurni da želite da obrišete ovaj transekt?',
      );
      expect(
        'delete_point_confirm'.tr(),
        'Da li ste sigurni da želite da obrišete ovu tačku?',
      );
      expect(
        'delete_record_confirm'.tr(),
        'Da li ste sigurni da želite da obrišete ovaj zapis?',
      );
      expect('transect_deleted'.tr(), 'Transekt je obrisan');
      expect('delete'.tr(), 'Obriši');
      expect('transect'.tr(), 'Transekt');
      expect('about'.tr(), 'O aplikaciji');
    });

    testWidgets('showDeleteWithPhotosDialog uses custom title when provided', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          localizedTestApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteWithPhotosDialog(
                  const [],
                  (_) {},
                  title: 'Custom delete title',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.pump();
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Custom delete title'), findsOneWidget);
    });

    testWidgets('showDeleteWithPhotosDialog with photos uses custom title', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          localizedTestApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDeleteWithPhotosDialog(
                  ['photo1.jpg'],
                  (_) {},
                  title: 'Delete point title',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.pump();
      });
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Delete point title'), findsOneWidget);
    });
  });

  group('record form shell', () {
    Future<void> pump(WidgetTester tester, Widget form) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(localizedTestApp(home: Scaffold(body: form)));
        await tester.pump();
      });
      await tester.pumpAndSettle();
    }

    testWidgets('collects the species and the app fields', (tester) async {
      TrackerRecord? saved;
      await pump(
        tester,
        RecordFormShell(onSaved: (record, close) => saved = record),
      );
      await tester.enterText(find.byType(EditableText).first, 'Parus major');
      await tester.enterText(find.byKey(const ValueKey('note')), 'pevanje');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final record = saved as TestRecord;
      expect(record.species, 'Parus major');
      expect(record.note, 'pevanje');
      expect(record.photos, isEmpty);
    });

    testWidgets('a single-species app has no species field, and one record '
        'per point has no "Save and new"', (tester) async {
      TrackerConfig.current = testConfig(
        catalog: null,
        singleRecordPerPoint: true,
      );
      addTearDown(() => TrackerConfig.current = testConfig());

      TrackerRecord? saved;
      await pump(
        tester,
        RecordFormShell(onSaved: (record, close) => saved = record),
      );
      expect(find.text('Species'), findsNothing);
      expect(find.text('Save and new'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('note')), 'gnezdo');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((saved as TestRecord).note, 'gnezdo');
      expect(saved!.species, '');
    });
  });
}
