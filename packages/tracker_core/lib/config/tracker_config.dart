import 'package:flutter/widgets.dart';

import '../model/placemark.dart';

/// One observation on a point. What an app records about it — a breeding
/// code, a development stage, a nest position — is the app's business; this
/// is the part the shared code needs to store, list and export it.
abstract class TrackerRecord {
  /// Latin name the record is about. An app that tracks a single species
  /// returns a constant.
  String get species;

  /// File names only, never paths — the app documents directory moves between
  /// installs on iOS. Resolve through [MediaService.fileFor] when reading.
  abstract List<String> photos;

  /// Persisted shape; [TrackerConfig.recordFromJson] is its inverse. Anything
  /// in here round-trips through the database, the backup and the KML payload.
  Map<String, dynamic> toJson();

  /// One-line, human-readable rendering: the KML placemark description and
  /// the balloon in Google Earth.
  String get summary;

  /// The line under the species name in the point's record list.
  String get subtitle;
}

/// An entry the app adds to the drawer's configuration section.
class TrackerMenuItem {
  const TrackerMenuItem({
    required this.titleKey,
    required this.icon,
    required this.onTap,
  });

  /// Translation key of the title.
  final String titleKey;
  final IconData icon;
  final VoidCallback onTap;
}

/// The domain half of the record form. [RecordFormShell] wraps it in the
/// [Form], puts the species field above it and the buttons below, and hands
/// it the photo strip so the fields decide where that sits. Validators in the
/// fields run with the shell's form; on a valid save the shell asks [collect]
/// for the record.
abstract class RecordFieldsState<T extends StatefulWidget> extends State<T> {
  /// Build the record from the current field values. [species] is the shell's
  /// species field, empty when the app has no catalog; [existing] is the
  /// record being edited, so a timestamp taken at creation can be kept.
  TrackerRecord collect({required String species, TrackerRecord? existing});

  /// "Save and new": back to the defaults for the next record.
  void reset();
}

typedef RecordFieldsBuilder = Widget Function({
  required Key key,
  TrackerRecord? existing,
  required Widget photoStrip,
});

/// Everything that tells the shared code apart between one tracker app and
/// the next: branding, and the hooks the record type plugs into.
class TrackerConfig {
  const TrackerConfig({
    required this.appTitle,
    required this.logoAsset,
    required this.galleryAlbum,
    required this.photoPrefix,
    required this.dbName,
    required this.backupBaseName,
    required this.kmlNamespace,
    required this.kmlPrefix,
    required this.androidPackage,
    required this.speciesCatalog,
    this.speciesTranslationKey = defaultSpeciesTranslationKey,
    this.singleRecordPerPoint = false,
    required this.recordFromJson,
    this.recordsFromLegacyDescription,
    required this.exportColumnLabels,
    required this.exportValues,
    required this.recordFields,
    this.extraMenuItems = const [],
  });

  // ── Branding ──────────────────────────────────────────────────────────

  /// Shown in the app bar and used in translated texts as `{app}`.
  final String appTitle;

  /// SVG asset of the logo, e.g. `assets/icons/logo.svg`.
  final String logoAsset;

  /// Album the photos show up under in the device gallery.
  final String galleryAlbum;

  /// Prefix of photo file names: `BT_20260504_211500_1a2b.jpg`.
  final String photoPrefix;

  /// File name of the sembast database inside the documents directory.
  final String dbName;

  /// Base name of the backup archive and of the records file inside it.
  final String backupBaseName;

  /// Namespace and prefix of the app's private KML ExtendedData payload.
  final String kmlNamespace;
  final String kmlPrefix;

  /// Android application id; the MainActivity method channel is named after
  /// it (`<package>/background_location`).
  final String androidPackage;

  // ── Domain ────────────────────────────────────────────────────────────

  /// Latin names offered by the species autocomplete. Null for an app that
  /// tracks a single species: the form then has no species field at all.
  final List<String>? speciesCatalog;

  /// Translation key of a catalog name's common name.
  final String Function(String latin) speciesTranslationKey;

  /// One record per point — a nest census, where the point is the nest. The
  /// point sheet then edits that record instead of offering to add more.
  final bool singleRecordPerPoint;

  /// Inverse of [TrackerRecord.toJson].
  final TrackerRecord Function(Map<String, dynamic> json) recordFromJson;

  /// Parser for the prose `<description>` of a KML placemark, for exports
  /// from before the ExtendedData payload existed. Null when the app never
  /// shipped such exports.
  final List<TrackerRecord> Function(String description)?
      recordsFromLegacyDescription;

  /// Column headers of one record row in the CSV export, in order — also the
  /// names of the `<Data>` rows a KML viewer shows in the balloon. Called at
  /// export time so the labels follow the app language.
  final List<String> Function() exportColumnLabels;

  /// Values for [exportColumnLabels], same order, same length. Empty rather
  /// than absent for a field the surveyor left blank.
  final List<String> Function(Placemark point, TrackerRecord record)
      exportValues;

  /// The app's fields of the record form; see [RecordFieldsState].
  final RecordFieldsBuilder recordFields;

  /// Extra entries in the drawer's configuration section.
  final List<TrackerMenuItem> extraMenuItems;

  // ── Current ───────────────────────────────────────────────────────────

  static TrackerConfig? _current;

  /// The running app's config. [runTrackerApp] sets it; tests set it directly.
  static TrackerConfig get current {
    final config = _current;
    if (config == null) {
      throw StateError('TrackerConfig.current is not set — call runTrackerApp '
          'or assign TrackerConfig.current in the test setUp');
    }
    return config;
  }

  static set current(TrackerConfig config) => _current = config;

  /// Name of the MainActivity method channel.
  String get backgroundLocationChannel => '$androidPackage/background_location';
}

/// easy_localization reads a dot in a key as a path separator, so a species
/// name like "Anas sp." would resolve to "" and come back as the raw key; the
/// dotted names are stored under an underscore instead ("Anas sp_"). The
/// Latin name itself is untouched — it is what records, CSV and KML carry.
String defaultSpeciesTranslationKey(String name) =>
    'species.${name.replaceAll('.', '_')}';
