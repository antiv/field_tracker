import 'dart:convert';
import 'dart:io';

import 'package:bird_tracker/configuration/species.dart';
import 'package:bird_tracker/model/species.dart';
import 'package:bird_tracker/service/data_service.dart';
import 'package:bird_tracker/service/media_service.dart';
import 'package:bird_tracker/widgets/species_form.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

late Directory mediaRoot;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await DataService().initPreferences();

    /// dart:io futures never resolve inside testWidgets' fake async, so the
    /// media store is set up out here where the clock is real
    mediaRoot = await Directory.systemTemp.createTemp('bird_form_test');
    await MediaService().init(root: mediaRoot.path);
  });

  tearDownAll(() async {
    if (mediaRoot.existsSync()) await mediaRoot.delete(recursive: true);
  });

  testWidgets('every catalog name has a translation in both locales',
      (tester) async {
    /// easy_localization treats a dot in a key as a path separator, so
    /// "Anas sp." used to come back as the raw key in the autocomplete —
    /// speciesTranslationKey maps such names to their underscore keys
    for (final locale in const [Locale('en'), Locale('sr', 'Latn')]) {
      await pumpForm(tester, const SizedBox(), startLocale: locale);
      for (final name in kSpecies) {
        final key = speciesTranslationKey(name);
        expect(key.tr(), isNot(key), reason: '$name in $locale');
      }
    }
  });

  testWidgets('shows the record fields and the photo strip', (tester) async {
    await pumpForm(tester, const SpeciesForm());

    expect(find.text('Species'), findsOneWidget);
    expect(find.text('Count'), findsOneWidget);
    expect(find.text('Behavior'), findsOneWidget);
    expect(find.text('Select atlas code'), findsOneWidget);
    expect(find.text('Direction:'), findsOneWidget);
    expect(find.text('Strat.:'), findsOneWidget);

    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);

    /// the time is stamped silently, so it has no input
    expect(find.text('Time'), findsNothing);
  });

  testWidgets('saves a record with an automatic timestamp', (tester) async {
    Species? saved;
    await pumpForm(
        tester, SpeciesForm(onSaved: (species, close) => saved = species));

    await tester.enterText(find.byType(EditableText).first, 'Parus major');
    await tester.pumpAndSettle();

    /// the photo strip pushed the buttons past the default 800x600 viewport
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.species, 'Parus major');
    expect(saved!.count, 1);
    expect(saved!.photos, isEmpty);

    /// hh:mm:ss stamped at save time, not entered by the surveyor
    expect(saved!.time, matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')));
  });

  testWidgets('lays out on a phone in Serbian, where the labels are longest',
      (tester) async {
    tester.view.physicalSize = const Size(1206, 2622); // iPhone 16 Pro
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpForm(tester, const SpeciesForm(),
        startLocale: const Locale('sr', 'Latn'));

    expect(find.text('Vrsta'), findsOneWidget);
    expect(find.text('Izaberi atlas kod'), findsOneWidget);
    expect(find.text('Ponašanje'), findsOneWidget);

    /// the photo strip carries the longest Serbian button labels
    expect(find.text('Fotografije'), findsOneWidget);
    expect(find.text('Galerija'), findsOneWidget);
    expect(find.text('Sačuvaj i dodaj novo'), findsOneWidget);
    // a RenderFlex overflow would have been thrown by now
  });

  testWidgets('editing a record leaves its photos on disk', (tester) async {
    const photo = 'BT_20260504_211530_0a1b.jpg';

    final existing = Species()
      ..species = 'Sitta europaea'
      ..time = '10:00:00'
      ..count = 2
      ..code = null
      ..description = null
      ..photos = [photo];

    Species? saved;
    await pumpForm(
        tester,
        SpeciesForm(
            species: existing, onSaved: (species, close) => saved = species));

    /// written after the pump on purpose: an Image.file that resolves starts
    /// an image decode the test binding only completes inside runAsync, and
    /// pumpAndSettle would then never settle
    MediaService()
        .fileFor(photo)
        .writeAsBytesSync(base64Decode('R0lGODlhAQABAAAAACw='), flush: true);

    await tester.ensureVisible(find.text('Save'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved!.photos, [photo]);

    /// the form disposes here; a photo the saved record still lists must not
    /// be swept up as an abandoned one
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();
    expect(MediaService().exists(photo), isTrue);

    MediaService().fileFor(photo).deleteSync();
  });

  testWidgets('editing a record offers Save only, not "Save and new"',
      (tester) async {
    final existing = Species()
      ..species = 'Sitta europaea'
      ..time = '10:00:00'
      ..count = 2
      ..code = 12
      ..description = null;

    await pumpForm(tester, SpeciesForm(species: existing));

    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Save and new'), findsNothing);

    /// the atlas code the record already carries shows on the button
    expect(find.textContaining('12'), findsWidgets);
  });
}
