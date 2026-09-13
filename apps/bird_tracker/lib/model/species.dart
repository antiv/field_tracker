import 'package:collection/collection.dart';

class Species {
  late String species;
  late String time; // hh:mm:ss
  late int count;
  late int? code;

  late String? description;

  Stratification? stratification;
  Direction? direction;

  /// File names only, never paths — the app documents directory moves between
  /// installs on iOS. Resolve through [MediaService.fileFor] when reading.
  List<String> photos = [];

  Map<String, dynamic> toJson() => {
        'species': species,
        'time': time,
        'count': count,
        'code': code,
        'description': description,
        'stratification': stratification?.name,
        'direction': direction?.name,
        'photos': photos,
      };

  static Species fromJson(Map<String, dynamic> json) => Species()
    ..species = json['species'] as String
    ..time = json['time'] as String
    ..count = json['count'] as int
    ..code = json['code'] as int?
    ..description = json['description'] as String?
    ..stratification = json['stratification'] != null
        ? Stratification.values.firstWhereOrNull(
            (e) => e.name == json['stratification'])
        : null
    ..direction = json['direction'] != null
        ? Direction.values.firstWhereOrNull(
            (e) => e.name == json['direction'])
        : null
    ..photos =
        (json['photos'] as List<dynamic>?)?.cast<String>().toList() ?? [];

  String get speciesString {
    return '$species: $count, ${code ?? '-'}, $time, ${stratification?.toShortString() ?? ''}, ${direction?.toShortString() ?? ''}; ${description ?? ''}';
  }

  List<Species>? listFromString(List<String> species) {
    return species.map((e) => Species.fromSpeciesString(e)).toList().whereType<Species>().toList();
  }

  static Species? fromSpeciesString(String e) {
    List<String> test = e.split(': ');
    if (test.length < 2) {
      return null;
    }
    /// remove first value from test and join the rest
    final String data = test.sublist(1).join(': ');
    if (data.split(', ').length < 5) {
      return null;
    }
    String species = e.split(': ')[0];
    String rest = e.split(': ')[1];
    List<String> parts = rest.split(', ');
    return Species()
      ..species = species
      ..count = int.tryParse(parts[0]) ?? 1
      ..code = int.tryParse(parts[1])
      ..time = parts[2]
      ..stratification = Stratification.values
          .firstWhereOrNull((element) => element.toShortString() == parts[3])
      ..direction = Direction.values
          .firstWhereOrNull((element) => element.toShortString() == parts[4])
      ..description = parts.length < 6 ? null : '"${parts.sublist(5).join(', ')}"';
  }
}

enum Stratification {
  g,
  s,
  d,
}

extension StratificationExt on Stratification {
  String toShortString() {
    return toString().split('.').last.toUpperCase();
  }
}

enum Direction {
  n,
  nne,
  ne,
  ene,
  e,
  ese,
  se,
  sse,
  s,
  ssw,
  sw,
  wsw,
  w,
  wnw,
  nw,
  nnw,
}

extension DirectionExt on Direction {
  String toShortString() {
    return toString().split('.').last.toUpperCase();
  }

  bool isSub() => toShortString().length > 2;
}
