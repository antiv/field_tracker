import 'dart:developer';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// "Allow all the time" on Android, requested on its own.
///
/// Android 11+ ignores a permission request that asks for background location
/// together with the foreground ones — no system prompt appears and neither
/// permission is granted. The `location` plugin does exactly that inside
/// `enableBackgroundMode`, so the background grant is handled here through
/// MainActivity instead. On iOS the plugin's own always-authorization flow is
/// correct, so every call is a no-op success.
class BackgroundLocationPermission {
  static const MethodChannel _channel =
      MethodChannel('rs.antonijevic.bird_tracker/background_location');

  static Future<bool> isGranted() => _invoke('hasBackgroundPermission');

  /// Opens the system prompt (Android 11+ routes it to the app's location
  /// settings page). Resolves once the user is back, with the real state.
  static Future<bool> request() => _invoke('requestBackgroundPermission');

  /// Android 12+ "Approximate location": asks for ACCESS_FINE_LOCATION alone,
  /// which is what shows the system's upgrade-to-precise dialog — the plugin
  /// counts coarse as granted and never asks. Resolves with the real state.
  static Future<bool> requestPrecise() => _invoke('requestPrecisePermission');

  /// The app's own settings page — the only place left once a permission has
  /// been refused for good. iOS has no channel for it, but its settings URL
  /// scheme opens the same page.
  static Future<void> openSettings() async {
    if (Platform.isIOS) {
      await launchUrl(Uri.parse('app-settings:'));
      return;
    }
    if (!Platform.isAndroid) return;
    await _invoke('openAppSettings');
  }

  static Future<bool> _invoke(String method) async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on PlatformException catch (e) {
      log('Background location permission $method failed: ${e.message}');
      return false;
    } on MissingPluginException {
      log('Background location channel missing — old engine attached?');
      return false;
    }
  }
}
