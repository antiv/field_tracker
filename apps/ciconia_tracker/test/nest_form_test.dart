import 'dart:io';

import 'package:ciconia_tracker/configuration/options.dart';
import 'package:ciconia_tracker/domain/ciconia_config.dart';
import 'package:ciconia_tracker/domain/nest_record.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracker_core/testing.dart';
import 'package:tracker_core/tracker_core.dart';

/// EasyLocalization loads its JSON off the real asset bundle, which only
/// resolves inside [WidgetTester.runAsync] — without it the widget never gets
/// past its loading state on the second pump in a file.
Future<void> pumpForm(WidgetTester tester, Widget child,
    {Locale? startLocale}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(localizedTestApp(
        home: Scaffold(body: child), startLocale: startLocale));
    await tester.pump();
  });
  await tester.pumpAndSettle();
}

late Directory mediaRoot;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TrackerConfig.current = ciconiaConfig;
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await DataService().initPreferences();

    /// dart:io futures never resolve inside testWidgets' fake async, so the
    /// media store is set up out here where the clock is real
    mediaRoot = await Directory.systemTemp.createTemp('ciconia_form_test');
    await MediaService().init(root: mediaRoot.path);
  });

  tearDownAll(() async {
    if (mediaRoot.existsSync()) await mediaRoot.delete(recursive: true);
  });

  testWidgets('every option and code has a label in both locales',
      (tester) async {
    for (final locale in const [Locale('en'), Locale('sr', 'Latn')]) {
      await pumpForm(tester, const SizedBox(), startLocale: locale);
      for (final option in [...NestPosition.values, ...NestState.values]) {
        expect(optionLabel(option), isNot(contains('.')),
            reason: '$option in $locale');
      }
      for (var code = 0; code <= 16; code++) {
        expect('codes.$code'.tr(), isNot('codes.$code'),
            reason: 'code $code in $locale');
      }
    }
  });

  testWidgets('one species, one nest per point: no species field, no '
      '"Save and new"', (tester) async {
    await pumpForm(tester, const RecordFormShell());

    expect(find.text('Species'), findsNothing);
    expect(find.text('Save and new'), findsNothing);
    expect(find.text('Nest position'), findsOneWidget);
    expect(find.text('Nest state'), findsOneWidget);
    expect(find.text('Young'), findsOneWidget);
    expect(find.text('Select atlas code'), findsOneWidget);
    expect(find.text('Photos'), findsOneWidget);
  });

  testWidgets('saves a nest with an automatic timestamp', (tester) async {
    NestRecord? saved;
    await pumpForm(
        tester,
        RecordFormShell(
            onSaved: (record, close) => saved = record as NestRecord));

    await tester.enterText(find.widgetWithText(TextFormField, 'Place'),
        'Bački Monoštor');
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.species, kStork);
    expect(saved!.place, 'Bački Monoštor');
    expect(saved!.count, 0);
    expect(saved!.time, matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')));
  });

  testWidgets('lays out on a phone in Serbian, where the labels are longest',
      (tester) async {
    tester.view.physicalSize = const Size(1206, 2622); // iPhone 16 Pro
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpForm(tester, const RecordFormShell(),
        startLocale: const Locale('sr', 'Latn'));

    expect(find.text('Položaj gnezda'), findsOneWidget);
    expect(find.text('Stanje u gnezdu'), findsOneWidget);
    expect(find.text('Izaberi atlas kod'), findsOneWidget);
    expect(find.text('Fotografije'), findsOneWidget);
    // a RenderFlex overflow would have been thrown by now
  });
}
