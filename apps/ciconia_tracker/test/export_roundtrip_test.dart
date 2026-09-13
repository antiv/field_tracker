import 'dart:convert';

import 'package:ciconia_tracker/configuration/options.dart';
import 'package:ciconia_tracker/domain/ciconia_config.dart';
import 'package:ciconia_tracker/domain/nest_record.dart';
import 'package:ciconia_tracker/widgets/user_details_form.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracker_core/testing.dart';
import 'package:tracker_core/tracker_core.dart';
import 'package:xml/xml.dart';

Transect buildTransect() {
  final nest = NestRecord()
    ..time = '10:15:30'
    ..count = 3
    ..code = 16
    ..position = NestPosition.powerPolePlatform
    ..state = NestState.occupiedWithYoung
    ..place = 'Bački Monoštor'
    ..municipality = 'Sombor'
    ..description = 'Platforma, "nova"'
    ..photos = ['CT_20260504_101530_0a1b.jpg'];

  return Transect()
    ..id = 1
    ..name = 'Popis 2026'
    ..startDate = DateTime(2026, 5, 4, 9)
    ..endDate = DateTime(2026, 5, 4, 12)
    ..points = [
      Point()
        ..latitude = 45.8
        ..longitude = 19.0
    ]
    ..markers = [
      Placemark(
        id: 0,
        startDate: DateTime(2026, 5, 4, 10, 15),
        endDate: DateTime(2026, 5, 4, 10, 20),
        latitude: 45.812345,
        longitude: 19.061234,
        altitude: 88.0,
        accuracy: 5.0,
        records: [nest],
      )
    ];
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TrackerConfig.current = ciconiaConfig;
    SharedPreferences.setMockInitialValues({
      kSurveyorNameKey: 'Petar Petrović',
      kSurveyorEmailKey: 'petar@example.com',
      kSurveyorPhoneKey: '+381601234567',
    });
    await EasyLocalization.ensureInitialized();
    await DataService().initPreferences();
  });

  testWidgets('CSV carries the census columns and the surveyor',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(localizedTestApp());
      await tester.pump();
    });
    await tester.pumpAndSettle();

    final lines = const LineSplitter().convert(buildTransect().toCSV());
    expect(lines.length, 2);
    expect(
      lines.first,
      'Date,Time,Latitude,Longitude,Latitude (DMS),Longitude (DMS),'
      'Nest position,Nest state,Young,Atlas code,Place,Municipality,Note,'
      'Surveyor,Email,Phone,Transect,Point,Photos',
    );
    expect(
      lines[1],
      startsWith('04.05.2026,10:15:30,45.812345,19.061234,'
          '"N 45° 48\' 44.44"" ","E 19° 3\' 40.44"" ",'
          'Low-voltage power pole — on a purpose-built platform,'
          'Occupied nest with visible young,3,16,Bački Monoštor,Sombor,'
          '"Platforma, ""nova""",Petar Petrović,petar@example.com,'
          '+381601234567,Popis 2026,1,CT_20260504_101530_0a1b.jpg'),
    );

    /// the balloon shows the same columns, and a single nest needs no numbering
    final placemark = XmlDocument.parse(buildTransect().toKML())
        .findAllElements('Placemark')
        .first;
    final rows = {
      for (final data in placemark.findAllElements('Data'))
        data.getAttribute('name')!: data.findElements('value').first.innerText
    };
    expect(rows['Nest state'], 'Occupied nest with visible young');
    expect(rows['Surveyor'], 'Petar Petrović');
  });

  test('a KML round trip restores the nest through the payload', () {
    final restored = KMLUtils()
        .kmlToTransect(buildTransect().toKML(), DateTime(2026, 5, 4));
    final marker = restored.markers!.single;
    expect(marker.altitude, 88.0);

    final nest = marker.records!.single as NestRecord;
    expect(nest.species, kStork);
    expect(nest.position, NestPosition.powerPolePlatform);
    expect(nest.state, NestState.occupiedWithYoung);
    expect(nest.count, 3);
    expect(nest.code, 16);
    expect(nest.place, 'Bački Monoštor');
    expect(nest.description, 'Platforma, "nova"');
    expect(nest.photos, ['CT_20260504_101530_0a1b.jpg']);
  });

  test('a record with nothing filled in still exports and restores', () {
    final bare = NestRecord()..time = '11:00:00';
    final json = bare.toJson();
    final back = NestRecord.fromJson(json);
    expect(back.count, 0);
    expect(back.position, isNull);
    expect(back.photos, isEmpty);
    expect(bare.summary, contains('11:00:00'));
  });
}
