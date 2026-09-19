import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:tracker_core/tracker_core.dart';

import '../configuration/options.dart';

/// The white stork, the only species this census records.
const String kStork = 'Ciconia ciconia';

/// One nest: where it sits, what is in it, how many young, the atlas
/// breeding code, and the place it belongs to. The point it is on is the
/// nest's location.
class NestRecord implements TrackerRecord {
  late String time; // hh:mm:ss
  int count = 0; // young in the nest
  int? code;
  NestPosition? position;
  NestState? state;
  String? place;
  String? municipality;
  String? description;

  @override
  String get species => kStork;

  @override
  List<String> photos = [];

  @override
  Map<String, dynamic> toJson() => {
        'species': species,
        'time': time,
        'count': count,
        'code': code,
        'position': position?.name,
        'state': state?.name,
        'place': place,
        'municipality': municipality,
        'description': description,
        'photos': photos,
      };

  static NestRecord fromJson(Map<String, dynamic> json) => NestRecord()
    ..time = json['time'] as String? ?? ''
    ..count = (json['count'] as num?)?.toInt() ?? 0
    ..code = (json['code'] as num?)?.toInt()
    ..position = NestPosition.values
        .firstWhereOrNull((e) => e.name == json['position'])
    ..state = NestState.values.firstWhereOrNull((e) => e.name == json['state'])
    ..place = json['place'] as String?
    ..municipality = json['municipality'] as String?
    ..description = json['description'] as String?
    ..photos =
        (json['photos'] as List<dynamic>?)?.cast<String>().toList() ?? [];

  @override
  String get summary {
    final parts = <String>[
      optionLabel(position),
      optionLabel(state),
      '${'young_label'.tr()} $count',
      if (code != null) '${'code_label'.tr()} $code',
      time,
      if (place?.isNotEmpty ?? false) place!,
      if (municipality?.isNotEmpty ?? false) municipality!,
      if (description?.isNotEmpty ?? false) description!,
    ];
    return parts.where((p) => p.isNotEmpty).join(', ');
  }

  @override
  String get subtitle => [
        optionLabel(state),
        '${'young_label'.tr()} $count',
        time,
      ].where((p) => p.isNotEmpty).join(' • ');
}
