import 'package:easy_localization/easy_localization.dart';
import 'package:tracker_core/tracker_core.dart';

import '../configuration/field_options.dart';
import '../configuration/species.dart';
import 'herp_form_fields.dart';
import 'herp_record.dart';

const String kKmlNamespace = 'https://antonijevic.rs/herp_tracker';

/// Herp Tracker on top of tracker_core: branding, the herpetofauna catalog
/// and the observation record with its form and export columns.
final TrackerConfig herpConfig = TrackerConfig(
  appTitle: 'Herp Tracker',
  logoAsset: 'assets/icons/logo.svg',
  galleryAlbum: 'Herp Tracker',
  photoPrefix: 'HT',
  dbName: 'herp_tracker.db',
  backupBaseName: 'herp_tracker_backup',
  kmlNamespace: kKmlNamespace,
  kmlPrefix: 'herp',
  androidPackage: 'rs.antonijevic.herp_tracker',
  speciesCatalog: kSpecies,
  speciesTranslationKey: speciesKey,
  recordFromJson: HerpRecord.fromJson,
  exportColumnLabels: () => kRecordColumnKeys.map((k) => k.tr()).toList(),
  exportValues: herpExportValues,
  recordFields: ({required key, existing, required photoStrip}) =>
      HerpFormFields(
          key: key, existing: existing as HerpRecord?, photoStrip: photoStrip),
);

/// The export columns of one record, in the order of "Vrste za
/// aplikaciju.xlsx". CSV and the KML balloon are built from this same list,
/// so a new record field reaches both without a second edit.
const List<String> kRecordColumnKeys = [
  'csv_header.species',
  'csv_header.date',
  'csv_header.observed_at',
  'csv_header.lat',
  'csv_header.lon',
  'csv_header.altitude',
  'csv_header.accuracy',
  'csv_header.locality',
  'csv_header.stage',
  'csv_header.sex',
  'csv_header.data_type',
  'csv_header.method',
  'csv_header.habitat',
  'csv_header.water_bed',
  'csv_header.count',
  'csv_header.abundance',
  'csv_header.note',
];

/// Values for [kRecordColumnKeys], same order, same length. Empty rather
/// than absent for a field the surveyor left blank — the balloon shows the
/// row as "No value", which is information too.
List<String> herpExportValues(Placemark point, TrackerRecord record) {
  final herp = record as HerpRecord;
  return [
    herp.species,
    DateFormat('dd.MM.yyyy').format(herp.observedAt),
    DateFormat('dd.MM.yyyy HH:mm:ss').format(herp.observedAt),
    point.latitude?.toString() ?? '',
    point.longitude?.toString() ?? '',
    point.altitude?.toStringAsFixed(1) ?? '',
    point.accuracy?.toStringAsFixed(1) ?? '',
    herp.locality ?? '',
    optionLabel(herp.stage),
    optionLabel(herp.sex),
    optionLabel(herp.dataType),
    optionLabel(herp.method),
    optionLabel(herp.habitat),
    optionLabel(herp.waterBed),
    herp.count?.toString() ?? '',
    optionLabel(herp.abundance),
    herp.note ?? '',
  ];
}
