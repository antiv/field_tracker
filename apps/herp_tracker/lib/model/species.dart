import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';

import '../configuration/field_options.dart';

/// One observation record. Fields mirror the columns of
/// "Vrste za aplikaciju.xlsx"; the point-level ones (LAT, LONG, altitude,
/// GPS accuracy) live on the parent [Placemark].
class Species {
  late String species;

  /// Filled automatically when the record is saved — covers both the "Datum"
  /// and "Datum posmatranja" export columns. Not editable in the form.
  late DateTime observedAt;

  String? locality;
  DevelopmentStage? stage;
  Sex? sex;
  int? count;
  AbundanceRange? abundance;

  /// Advanced fields
  DataType? dataType;
  CollectionMethod? method;
  HabitatType? habitat;
  WaterBedType? waterBed;
  String? note;

  /// File names only, never paths — the app documents directory moves between
  /// installs on iOS. Resolve through [MediaService.fileFor] when reading.
  List<String> photos = [];

  Map<String, dynamic> toJson() => {
        'species': species,
        'observedAt': observedAt.toIso8601String(),
        'locality': locality,
        'stage': stage?.name,
        'sex': sex?.name,
        'count': count,
        'abundance': abundance?.name,
        'dataType': dataType?.name,
        'method': method?.name,
        'habitat': habitat?.name,
        'waterBed': waterBed?.name,
        'note': note,
        'photos': photos,
      };

  static Species fromJson(Map<String, dynamic> json) => Species()
    ..species = json['species'] as String
    ..observedAt =
        DateTime.tryParse(json['observedAt'] as String? ?? '') ?? DateTime.now()
    ..locality = json['locality'] as String?
    ..stage =
        DevelopmentStage.values.firstWhereOrNull((e) => e.name == json['stage'])
    ..sex = Sex.values.firstWhereOrNull((e) => e.name == json['sex'])
    ..count = (json['count'] as num?)?.toInt()
    ..abundance = AbundanceRange.values
        .firstWhereOrNull((e) => e.name == json['abundance'])
    ..dataType =
        DataType.values.firstWhereOrNull((e) => e.name == json['dataType'])
    ..method = CollectionMethod.values
        .firstWhereOrNull((e) => e.name == json['method'])
    ..habitat =
        HabitatType.values.firstWhereOrNull((e) => e.name == json['habitat'])
    ..waterBed =
        WaterBedType.values.firstWhereOrNull((e) => e.name == json['waterBed'])
    ..note = json['note'] as String?
    ..photos = (json['photos'] as List<dynamic>?)?.cast<String>().toList() ?? [];

  /// Localized one-line summary, used in lists and in the KML description.
  String get speciesString {
    final parts = <String>[
      if (count != null) '${'count_label'.tr()} $count',
      if (abundance != null) abundance!.label,
      if (stage != null) optionLabel(stage),
      if (sex != null) optionLabel(sex),
      DateFormat('HH:mm:ss').format(observedAt),
      if (locality?.isNotEmpty ?? false) locality!,
      if (note?.isNotEmpty ?? false) note!,
    ];
    return '$species: ${parts.join(', ')}';
  }
}
