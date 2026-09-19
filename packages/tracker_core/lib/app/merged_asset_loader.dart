import 'dart:convert';
import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Translations come from two places: the shared UI strings bundled with
/// tracker_core, and the app's own file with its species names, field labels
/// and any shared key it wants to word differently. The app's file wins on a
/// key both define.
class MergedAssetLoader extends AssetLoader {
  const MergedAssetLoader();

  static const String corePath = 'packages/tracker_core/assets/translations';

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    final core = await _read('$corePath/${_fileName(locale)}');
    final app = await _read('$path/${_fileName(locale)}');
    return merge(core, app);
  }

  static String _fileName(Locale locale) => '${locale.toStringWithSeparator(separator: '-')}.json';

  /// A missing app file is fine — a locale the app has nothing to add to.
  static Future<Map<String, dynamic>> _read(String asset) async {
    try {
      final text = await rootBundle.loadString(asset);
      return Map<String, dynamic>.from(jsonDecode(text) as Map);
    } on FlutterError {
      return {};
    }
  }

  /// Nested blocks (`species`, `csv_header`) merge key by key too, so the app
  /// can add to one without restating it.
  @visibleForTesting
  static Map<String, dynamic> merge(
      Map<String, dynamic> base, Map<String, dynamic> over) {
    final out = Map<String, dynamic>.from(base);
    over.forEach((key, value) {
      final existing = out[key];
      out[key] = value is Map && existing is Map
          ? merge(Map<String, dynamic>.from(existing),
              Map<String, dynamic>.from(value))
          : value;
    });
    return out;
  }
}
