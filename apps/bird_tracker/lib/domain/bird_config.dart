import 'package:easy_localization/easy_localization.dart';
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

/// The bird CSV columns as `csv_header.*` keys, in the order the survey
/// sheet wants them. The core puts the point number before them and the
/// transect and photos after them.
const List<String> kBirdColumnKeys = [
  'species',
  'date',
  'time_range',
  'time',
  'lat',
  'lon',
  'lat_dms',
  'lon_dms',
  'count',
  'distance',
  'direction',
  'comment',
  'stratification',
  'flight_direction',
  'code',
];

/// Headers follow the app language, like the core's own columns.
List<String> birdExportColumns() =>
    [for (final key in kBirdColumnKeys) 'csv_header.$key'.tr()];

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
    bird.distance ?? '',
    bird.sightingDirection?.toShortString() ?? '',
    bird.description ?? '',
    bird.stratification?.toShortString() ?? '',
    bird.direction?.toShortString() ?? '',
    bird.code?.toString() ?? '',
  ];
}
