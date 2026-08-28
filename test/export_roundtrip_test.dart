import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herp_tracker/configuration/field_options.dart';
import 'package:herp_tracker/model/placemark.dart';
import 'package:herp_tracker/model/point.dart';
import 'package:herp_tracker/model/species.dart';
import 'package:herp_tracker/model/transect.dart';
import 'package:herp_tracker/utils/kml_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

Transect buildTransect() {
  final record = Species()
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
    ..note = 'Uz put, "kod mosta"; kiša';

  final second = Species()
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
        species: [record, second],
      )
    ];
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('CSV and KML carry every record field', (tester) async {
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('sr', 'Latn')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const SizedBox(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    /// the CSV/KML share buttons use these as plain labels — nesting a block
    /// under the same key makes .tr() hand back a Map and the widget throws
    expect('csv'.tr(), 'CSV');
    expect('kml'.tr(), 'KML');

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
      'Transect,Point',
    );
    expect(
      lines[1],
      'Bufo bufo,04.05.2026,04.05.2026 21:15:30,44.812345,20.361234,117.4,4.8,'
      'Deliblatska peščara,Adult,F,Observation,Hand capture,'
      'Settlement and buildings,Muddy,3,2-5,'
      '"Uz put, ""kod mosta""; kiša",Test transekt,1',
    );
    // a record with only the required fields must still line up
    expect(lines[2].split(',').length, 19);

    // ── KML round trip ───────────────────────────────────────────────────
    final restored =
        KMLUtils().kmlToTransect(transect.toKML(), DateTime(2026, 5, 4));
    final marker = restored.markers!.single;
    expect(marker.latitude, 44.812345);
    expect(marker.longitude, 20.361234);
    expect(marker.altitude, 117.4);
    expect(marker.accuracy, 4.8);
    expect(restored.points!.length, 1);

    final back = marker.species!.first;
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
    expect(marker.species!.last.species, 'Natrix natrix');
  });
}
