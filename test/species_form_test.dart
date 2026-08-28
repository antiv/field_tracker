import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:herp_tracker/configuration/field_options.dart';
import 'package:herp_tracker/model/species.dart';
import 'package:herp_tracker/service/data_service.dart';
import 'package:herp_tracker/widgets/species_form.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// EasyLocalization loads its JSON off the real asset bundle, which only
/// resolves inside [WidgetTester.runAsync] — without it the widget never gets
/// past its loading state on the second pump in a file.
Future<void> pumpForm(WidgetTester tester, Widget child,
    {Locale? startLocale}) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('sr', 'Latn')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: startLocale,
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(body: child),
        ),
      ),
    ));
    await tester.pump();
  });
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await DataService().initPreferences();
  });

  testWidgets('shows the basic fields and hides the automatic ones',
      (tester) async {
    await pumpForm(tester, const SpeciesForm());

    expect(find.text('Species'), findsOneWidget);
    expect(find.text('Locality'), findsOneWidget);
    expect(find.text('Development stage'), findsOneWidget);
    expect(find.text('Sex'), findsOneWidget);
    expect(find.text('Count'), findsOneWidget);
    expect(find.text('Abundance range'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);

    // date, coordinates, altitude and accuracy are captured silently
    expect(find.text('LAT'), findsNothing);
    expect(find.text('LONG'), findsNothing);
    expect(find.text('Altitude'), findsNothing);
    expect(find.text('GPS accuracy'), findsNothing);
    expect(find.text('Observation date'), findsNothing);

    // advanced fields stay out of the way until asked for
    expect(find.text('Habitat type'), findsNothing);
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('Data type'), findsOneWidget);
    expect(find.text('Collection method'), findsOneWidget);
    expect(find.text('Habitat type'), findsOneWidget);
    expect(find.text('Water habitat bed type'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
  });

  testWidgets('saves a record with an automatic timestamp', (tester) async {
    Species? saved;
    await pumpForm(
        tester, SpeciesForm(onSaved: (species, close) => saved = species));

    await tester.enterText(
        find.byType(EditableText).first, 'Salamandra salamandra');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.species, 'Salamandra salamandra');
    expect(saved!.count, 1);
    expect(DateTime.now().difference(saved!.observedAt).inMinutes, lessThan(1));
  });

  testWidgets('lays out on a phone in Serbian, where the labels are longest',
      (tester) async {
    tester.view.physicalSize = const Size(1206, 2622); // iPhone 16 Pro
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpForm(tester, const SpeciesForm(),
        startLocale: const Locale('sr', 'Latn'));

    expect(find.text('Lokalitet'), findsOneWidget);
    expect(find.text('Razvojni stadijum'), findsOneWidget);
    // sex is the one list still shown as radios — all three fit on one line
    expect(find.text('oba'), findsOneWidget);
    expect(find.text('Opseg brojnosti'), findsOneWidget);

    await tester.tap(find.text('Napredno'));
    await tester.pumpAndSettle();
    expect(find.text('Tip dna vodenog staništa'), findsOneWidget);
    // a RenderFlex overflow would have been thrown by now
  });

  testWidgets('opens Advanced when editing a record that uses it',
      (tester) async {
    final existing = Species()
      ..species = 'Bombina variegata'
      ..observedAt = DateTime(2026, 5, 4, 10)
      ..count = 2
      ..habitat = HabitatType.puddle;

    await pumpForm(tester, SpeciesForm(species: existing));

    expect(find.text('Puddle'), findsOneWidget);
    // editing an existing record offers Save only, not "Save and new"
    expect(find.text('Save and new'), findsNothing);
  });
}
