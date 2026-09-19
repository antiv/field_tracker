import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:tracker_core/tracker_core.dart';

import '../configuration/options.dart';
import '../widgets/user_details_form.dart';
import 'nest_form_fields.dart';
import 'nest_record.dart';

const String kKmlNamespace = 'https://antonijevic.rs/ciconia_tracker';

/// "Popis roda" on top of tracker_core: a white stork nest census. One
/// species, so no species field; one nest per point; the surveyor's
/// details ride along in every export row.
final TrackerConfig ciconiaConfig = TrackerConfig(
  appTitle: 'Popis roda',
  logoAsset: 'assets/icons/logo.svg',
  galleryAlbum: 'Popis roda',
  photoPrefix: 'CT',
  dbName: 'ciconia_tracker.db',
  backupBaseName: 'ciconia_tracker_backup',
  kmlNamespace: kKmlNamespace,
  kmlPrefix: 'ct',
  speciesCatalog: null,
  singleRecordPerPoint: true,
  recordFromJson: NestRecord.fromJson,
  exportColumnLabels: () => kRecordColumnKeys.map((k) => k.tr()).toList(),
  exportValues: nestExportValues,
  recordFields: ({required key, existing, required photoStrip}) =>
      NestFormFields(
          key: key, existing: existing as NestRecord?, photoStrip: photoStrip),
  extraMenuItems: [
    TrackerMenuItem(
      titleKey: 'surveyor_details',
      icon: Icons.badge_outlined,
      onTap: () => showFullScreenDialog(const UserDetailsForm(),
          title: 'surveyor_details'.tr()),
    ),
  ],
);

/// The columns of the census sheet, in its order. CSV and the KML balloon
/// are built from this same list.
const List<String> kRecordColumnKeys = [
  'csv_header.date',
  'csv_header.time',
  'csv_header.lat',
  'csv_header.lon',
  'csv_header.lat_dms',
  'csv_header.lon_dms',
  'csv_header.position',
  'csv_header.state',
  'csv_header.young',
  'csv_header.code',
  'csv_header.place',
  'csv_header.municipality',
  'csv_header.note',
  'csv_header.surveyor',
  'csv_header.email',
  'csv_header.phone',
];

List<String> nestExportValues(Placemark point, TrackerRecord record) {
  final nest = record as NestRecord;
  final prefs = DataService();
  final date = point.startDate;
  final lat = point.latitude;
  final lon = point.longitude;
  return [
    date == null ? '' : DateFormat('dd.MM.yyyy').format(date),
    nest.time,
    lat?.toString() ?? '',
    lon?.toString() ?? '',
    lat == null ? '' : convertLatLng(lat, true),
    lon == null ? '' : convertLatLng(lon, false),
    optionLabel(nest.position),
    optionLabel(nest.state),
    nest.count.toString(),
    nest.code?.toString() ?? '',
    nest.place ?? '',
    nest.municipality ?? '',
    nest.description ?? '',
    prefs.getString(kSurveyorNameKey) ?? '',
    prefs.getString(kSurveyorEmailKey) ?? '',
    prefs.getString(kSurveyorPhoneKey) ?? '',
  ];
}
