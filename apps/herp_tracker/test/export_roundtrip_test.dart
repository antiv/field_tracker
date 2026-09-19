import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herp_tracker/configuration/field_options.dart';
import 'package:herp_tracker/domain/herp_config.dart';
import 'package:herp_tracker/domain/herp_record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracker_core/testing.dart';
import 'package:tracker_core/tracker_core.dart';
import 'package:xml/xml.dart';

Transect buildTransect() {
  final record = HerpRecord()
    ..species = 'Bufo bufo'
    ..observedAt = DateTime(2026, 5, 4, 21, 15, 30)
    ..locality = 'Deliblatska peščara'
    ..stage = DevelopmentStage.adult
    ..sex = Sex.female
    ..count = 3
    ..abundance = AbundanceRange.r2_5
    ..dataType = DataType.observation
    ..method = CollectionMethod.handCapture
    ..habitat = HabitatType.settlement
    ..waterBed = WaterBedType.muddy
    ..note = 'Uz put, "kod mosta"; kiša'
    ..photos = ['HT_20260504_211530_0a1b.jpg', 'weird, name.jpg'];

  final second = HerpRecord()
    ..species = 'Natrix natrix'
    ..observedAt = DateTime(2026, 5, 4, 21, 40, 0)
    ..count = 1;

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
        altitude: 117.4,
        accuracy: 4.8,
        records: [record, second],
      )
    ];
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TrackerConfig.current = herpConfig;
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  test('a KML from before the namespaced payload still imports', () {
    /// exports already shared with colleagues carry the records in a plain
    /// <Data name="records">, which viewers used to print at the user
    const legacy = '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
<Document>
<name>Stari transekt</name>
<Placemark id="marker0">
<name>Point 1</name>
<description>Salamandra salamandra</description>
<ExtendedData>
<Data name="records">
<value>{"altitude":38.9,"accuracy":16.2,"startDate":"2026-08-30T15:31:28.000","endDate":"2026-08-30T15:32:40.000","species":[{"species":"Salamandra salamandra","observedAt":"2026-08-30T15:31:28.000","count":1,"stage":"adult","photos":["HT_20260830_153126_6db2.jpg"]}]}</value>
</Data>
</ExtendedData>
<Point><coordinates>20.60757,38.6235</coordinates></Point>
</Placemark>
</Document>
</kml>''';

    final imported = KMLUtils().kmlToTransect(legacy, DateTime(2026, 8, 30));
    final marker = imported.markers!.single;
    expect(marker.altitude, 38.9);
    expect(marker.accuracy, 16.2);

    final record = marker.records!.single as HerpRecord;
    expect(record.species, 'Salamandra salamandra');
    expect(record.count, 1);
    expect(record.stage, DevelopmentStage.adult);
    expect(record.photos, ['HT_20260830_153126_6db2.jpg']);
  });

  test('coordinates the map cannot place are dropped on import', () {
    /// `double.parse('NaN')` succeeds in Dart, and the Maps renderer kills
    /// the process on its own thread when handed a NaN target — so neither
    /// a KML nor a backup may carry one through to the map
    const kml = '''
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
<Document>
<name>Los</name>
<Placemark><name>Point 1</name><description>Bufo bufo</description>
<Point><coordinates>NaN,NaN</coordinates></Point></Placemark>
<Placemark><name>Point 2</name><description>Bufo bufo</description>
<Point><coordinates>20.36,44.81</coordinates></Point></Placemark>
<Placemark><name>Ruta</name>
<LineString><coordinates>
  20.36,44.81 NaN,44.82
	20.37,Infinity	20.38,44.83
</coordinates></LineString>
</Placemark>
</Document>
</kml>''';

    /// the route is split on any whitespace — Google Earth writes one tuple
    /// per line — and only the two placeable tuples survive
    final imported = KMLUtils().kmlToTransect(kml, DateTime(2026, 8, 30));
    expect(imported.markers!.map((m) => m.latitude), [44.81]);
    expect(imported.points!.map((p) => p.longitude), [20.36, 20.38]);

    final restored = Transect.fromJson({
      'startDate': '2026-08-30T10:00:00.000',
      'points': [
        {'latitude': 44.81, 'longitude': 20.36},
        {'latitude': double.nan, 'longitude': 20.37},
        {'latitude': 44.82, 'longitude': null},
      ],
      'markers': [
        {'id': 0, 'latitude': double.nan, 'longitude': 20.36, 'species': []},
      ],
    });
    expect(restored.points!.map((p) => p.latitude), [44.81]);
    expect(restored.markers!.single.hasFiniteLatLng, isFalse);
  });

  testWidgets('the KML balloon shows every field as its own row',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(localizedTestApp());
      await tester.pump();
    });
    await tester.pumpAndSettle();

    final kml = buildTransect().toKML();
    final placemark = XmlDocument.parse(kml)
        .findAllElements('Placemark')
        .firstWhere((p) => p.getAttribute('id') == 'marker0');
    final rows = {
      for (final data in placemark.findAllElements('Data'))
        data.getAttribute('name')!: data.findElements('value').first.innerText
    };

    /// the point holds two records, so every row is numbered — otherwise the
    /// table would repeat "Species" with nothing to tell the rows apart
    expect(rows['1. Species'], 'Bufo bufo');
    expect(rows['2. Species'], 'Natrix natrix');

    /// labels are the CSV headers in the app language, not raw keys
    expect(rows.keys, isNot(contains(anyElement(contains('csv_header')))));
    expect(rows['1. Development stage'], 'Adult');
    expect(rows['1. Exact number of individuals'], '3');
    expect(rows['1. Photos'], 'HT_20260504_211530_0a1b.jpg; weird, name.jpg');

    /// a field the surveyor left blank still gets a row — the viewer shows it
    /// as "No value", which is information too
    expect(rows.containsKey('2. Note'), isTrue);
    expect(rows['2. Note'], '');

    /// every record column, for both records, plus the photo row
    expect(rows.length, (kRecordColumnKeys.length + 1) * 2);

    /// the machine payload stays, namespaced so viewers skip it
    expect(
        placemark
            .findAllElements(kRecordsDataName, namespaceUri: kKmlNamespace)
            .length,
        1);
  });

  testWidgets('CSV and KML carry every record field', (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(localizedTestApp());
      await tester.pump();
    });
    await tester.pumpAndSettle();

    /// the CSV/KML share buttons use these as plain labels — nesting a block
    /// under the same key makes .tr() hand back a Map and the widget throws
    expect('csv'.tr(), 'CSV');
    expect('kml'.tr(), 'KML');
    expect('kmz'.tr(), 'KMZ');

    final transect = buildTransect();

    // ── CSV ──────────────────────────────────────────────────────────────
    final csv = transect.toCSV();
    final lines = const LineSplitter().convert(csv);
    expect(lines.length, 3);
    expect(
      lines.first,
      'Species,Date,Observation date,LAT,LONG,Altitude,GPS accuracy,Locality,'
      'Development stage,Sex,Data type,Collection method,Habitat type,'
      'Water habitat bed type,Exact number of individuals,Abundance range,Note,'
      'Transect,Point,Photos',
    );
    expect(
      lines[1],
      'Bufo bufo,04.05.2026,04.05.2026 21:15:30,44.812345,20.361234,117.4,4.8,'
      'Deliblatska peščara,Adult,F,Observation,Hand capture,'
      'Settlement and buildings,Muddy,3,2-5,'
      '"Uz put, ""kod mosta""; kiša",Test transekt,1,'
      '"HT_20260504_211530_0a1b.jpg; weird, name.jpg"',
    );
    // a record with only the required fields must still line up
    expect(lines[2].split(',').length, 20);

    // ── KML round trip ───────────────────────────────────────────────────
    final restored =
        KMLUtils().kmlToTransect(transect.toKML(), DateTime(2026, 5, 4));
    final marker = restored.markers!.single;
    expect(marker.latitude, 44.812345);
    expect(marker.longitude, 20.361234);
    expect(marker.altitude, 117.4);
    expect(marker.accuracy, 4.8);
    expect(restored.points!.length, 1);

    final back = marker.records!.first as HerpRecord;
    expect(back.species, 'Bufo bufo');
    expect(back.observedAt, DateTime(2026, 5, 4, 21, 15, 30));
    expect(back.locality, 'Deliblatska peščara');
    expect(back.stage, DevelopmentStage.adult);
    expect(back.sex, Sex.female);
    expect(back.count, 3);
    expect(back.abundance, AbundanceRange.r2_5);
    expect(back.dataType, DataType.observation);
    expect(back.method, CollectionMethod.handCapture);
    expect(back.habitat, HabitatType.settlement);
    expect(back.waterBed, WaterBedType.muddy);
    expect(back.note, 'Uz put, "kod mosta"; kiša');
    expect(back.photos, ['HT_20260504_211530_0a1b.jpg', 'weird, name.jpg']);
    expect(marker.records!.last.photos, isEmpty);
    expect(marker.records!.last.species, 'Natrix natrix');
  });
}
