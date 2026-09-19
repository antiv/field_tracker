/// Support for the apps' widget tests: the localization setup the real app
/// has, without the platform channels it also has.
library;

import 'package:context_holder/context_holder.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'app/merged_asset_loader.dart';
import 'app/tracker_app.dart';

/// A MaterialApp with the app's translations loaded the way [runTrackerApp]
/// loads them — core strings first, the app's file on top. Pump it inside
/// `tester.runAsync`: EasyLocalization reads its JSON off the real asset
/// bundle, which only resolves there; then `pumpAndSettle`.
Widget localizedTestApp({Widget home = const SizedBox(), Locale? startLocale}) {
  return EasyLocalization(
    supportedLocales: kSupportedLocales,
    path: 'assets/translations',
    assetLoader: const MergedAssetLoader(),
    fallbackLocale: kFallbackLocale,
    startLocale: startLocale,
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,

        /// as the real app does: ux_builder's dialogs and snackbars reach for
        /// the navigator through ContextHolder, and without the key every one
        /// of them throws on a null context
        navigatorKey: ContextHolder.key,
        home: home,
      ),
    ),
  );
}
