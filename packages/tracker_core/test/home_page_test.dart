import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracker_core/testing.dart';
import 'package:tracker_core/tracker_core.dart';

import 'test_config.dart';

/// The location and maps plugins have no implementation under the test
/// binding, so nothing can start recording here — which is exactly the
/// state this file is about: the map up, no transect.
Future<void> pumpHome(WidgetTester tester) async {
  await tester.runAsync(() async {
    /// .value, not create: DataService is a singleton, and a provider that
    /// owns it disposes it when the first test tears down
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: DataService(),
      child: localizedTestApp(home: const HomePage()),
    ));
    await tester.pump();
  });
  await tester.pump(const Duration(seconds: 1));
}

late Directory documents;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TrackerConfig.current = testConfig();
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    await DataService().initPreferences();

    /// sembast and the media store want the documents directory; dart:io
    /// futures only resolve out here, where the clock is real
    documents = await Directory.systemTemp.createTemp('tracker_home_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => documents.path);
    await MediaService().init(root: documents.path);

    /// The map is a platform view, and creating one under the test binding
    /// fails with a MissingPluginException that surfaces as a test error —
    /// answer the create call with a texture id and the map is just a hole
    /// in the layout, which is all this file needs it to be. Its own channel
    /// is named after the view id, one per map built, so a handful are
    /// stubbed out rather than the one.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform_views,
        (call) async => call.method == 'create' ? 0 : null);
    for (var id = 0; id < 8; id++) {
      messenger.setMockMethodCallHandler(
          MethodChannel('plugins.flutter.io/google_maps_$id'),
          (call) async => null);
    }
  });

  tearDownAll(() async {
    if (documents.existsSync()) await documents.delete(recursive: true);
  });

  tearDown(() => DataService().clearTransect());

  testWidgets('with nothing recording, the dial offers no Pause or Stop',
      (tester) async {
    await pumpHome(tester);

    /// Stop used to be reachable for the frames between the tap that starts
    /// a transect and the permission flow that creates it, and it went
    /// straight at `transect!` — "Null check operator used on a null value".
    final dial = tester.widget<SpeedDial>(find.byType(SpeedDial));
    expect(dial.children, isEmpty);
    expect(find.text('pause'.tr()), findsNothing);
    expect(find.text('stop'.tr()), findsNothing);
  });

  testWidgets('tapping the dial with no location service throws nothing',
      (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byType(SpeedDial));
    await tester.pump(const Duration(seconds: 1));

    /// no transect was created — the permission gate could not pass — and
    /// the dial still has nothing that would act on one
    expect(DataService().transect, isNull);
    expect(tester.widget<SpeedDial>(find.byType(SpeedDial)).children, isEmpty);
    expect(tester.takeException(), isNull);
  });

  /// Not covered here: anything that needs a location fix. The dial's Stop
  /// only exists while the stream is running, and the stream needs the
  /// plugin — the resume dialog's "continue" hangs this binding. Those paths
  /// are a device check.
}
