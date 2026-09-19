import 'package:easy_localization/easy_localization.dart';

/// Where the nest sits. The values follow the census sheet; the enum name is
/// what the record stores and the export payload carries, the label shown
/// to the surveyor goes through `.tr()`.
enum NestPosition {
  powerPoleWires,
  powerPolePlatform,
  chimney,
  roof,
  haystack,
  tree,
}

/// What was found in the nest.
enum NestState {
  occupiedWithYoung,
  occupiedNoYoung,
  occupiedUnknown,
  empty,
}

/// Translation-key prefix per enum type, so one generic widget can label
/// them all.
String optionLabel(Object? value) {
  if (value == null) return '';
  return switch (value) {
    NestPosition v => 'position.${v.name}'.tr(),
    NestState v => 'state.${v.name}'.tr(),
    _ => value.toString(),
  };
}
