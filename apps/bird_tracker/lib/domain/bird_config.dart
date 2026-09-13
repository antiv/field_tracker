import 'package:intl/intl.dart';
import 'package:tracker_core/tracker_core.dart';

import '../configuration/species.dart';
import 'bird_form_fields.dart';
import 'bird_record.dart';

const String kKmlNamespace = 'https://antonijevic.rs/bird_tracker';

/// Bird Tracker on top of tracker_core: branding, the bird catalog and the
/// sighting record with its form and export columns.
final TrackerConfig birdConfig = TrackerConfig(
  appTitle: 'Bird Tracker',
  logoAsset: 'assets/icons/logo.svg',
  galleryAlbum: 'Bird Tracker',
  photoPrefix: 'BT',
  dbName: 'bird_tracker.db',
  backupBaseName: 'bird_tracker_backup',
  kmlNamespace: kKmlNamespace,
  kmlPrefix: 'bt',
  speciesCatalog: kSpecies,
  speciesTranslationKey: speciesTranslationKey,
  recordFromJson: BirdRecord.fromJson,
  recordsFromLegacyDescription: BirdRecord.listFromDescription,
  exportColumnLabels: birdExportColumns,
  exportValues: birdExportValues,
  recordFields: ({required key, existing, required photoStrip}) =>
      BirdFormFields(
          key: key, existing: existing as BirdRecord?, photoStrip: photoStrip),
);

/// The columns the bird CSV has always had, in that order and in English —
/// the sheets built on the export expect them so.
List<String> birdExportColumns() => const [
      'Species',
      'Date',
      'Time (from - to)',
      'Time',
      'Latitude',
      'Longitude',
      'Latitude(DMS)',
      'Longitude(DMS)',
      'Count',
      'Behavior',
      'Stratification',
      'Direction',
      'Code',
    ];

List<String> birdExportValues(Placemark point, TrackerRecord record) {
  final bird = record as BirdRecord;

  /// A KML imported from before the ExtendedData payload carries no
  /// timestamps, so this is genuinely null — the same empty cell
  /// [Placemark.duration] already falls back to, rather than a crash on the
  /// way to the share sheet.
  final DateTime? date = point.startDate;
  final lat = point.latitude;
  final lon = point.longitude;
  return [
    bird.species,
    date == null ? '' : DateFormat('dd/MM/yyyy').format(date),
    point.duration,
    bird.time,
    lat?.toString() ?? '',
    lon?.toString() ?? '',
    lat == null ? '' : convertLatLng(lat, true),
    lon == null ? '' : convertLatLng(lon, false),
    bird.count.toString(),
    bird.description ?? '',
    bird.stratification?.toShortString() ?? '',
    bird.direction?.toShortString() ?? '',
    bird.code?.toString() ?? '',
  ];
}
