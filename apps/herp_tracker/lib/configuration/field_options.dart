import 'package:easy_localization/easy_localization.dart';

/// Enumerated record fields — values and their order come from
/// "Vrste za aplikaciju.xlsx" (rows 58-93).
///
/// Enum `name` is what gets stored in the database and in exports' machine
/// payloads; the label shown to the user always goes through `.tr()`.

/// Razvojni stadijum
enum DevelopmentStage { eggs, tadpoles, juvenile, adult }

/// Pol
enum Sex { male, female, both }

/// Tip podatka
enum DataType {
  collecting,
  observation,
  photographing,
  listening,
  potentiallyPresent
}

/// Metoda sakupljanja
enum CollectionMethod { handCapture, traps, echolocation, observation, other }

/// Tip staništa
enum HabitatType {
  forest,
  shrubland,
  park,
  sandDune,
  saltMarsh,
  rockyGround,
  scree,
  rock,
  treeLine,
  orchard,
  meadow,
  pasture,
  arableLand,
  monoculturePlantation,
  earthCut,
  gorge,
  riverIsland,
  reedbed,
  shore,
  lake,
  reservoir,
  settlingPond,
  pond,
  puddle,
  fishPond,
  marsh,
  peatBog,
  river,
  stream,
  spring,
  canal,
  gravelPit,
  settlement,
  openPitMine,
  landfill,
  other,
}

/// Tip dna vodenog staništa
enum WaterBedType {
  rocky,
  stony,
  gravelly,
  sandy,
  clayey,
  peaty,
  muddy,
  mixed,
  other,
}

/// Opseg brojnosti — labels are numeric ranges, identical in every language.
enum AbundanceRange {
  r2_5,
  r6_10,
  r11_50,
  r51_100,
  r101_250,
  r251_500,
  r501_1000,
  r1001_10000
}

extension AbundanceRangeExt on AbundanceRange {
  String get label => switch (this) {
        AbundanceRange.r2_5 => '2-5',
        AbundanceRange.r6_10 => '6-10',
        AbundanceRange.r11_50 => '11-50',
        AbundanceRange.r51_100 => '51-100',
        AbundanceRange.r101_250 => '101-250',
        AbundanceRange.r251_500 => '251-500',
        AbundanceRange.r501_1000 => '501-1000',
        AbundanceRange.r1001_10000 => '1001-10000',
      };
}

/// Translation-key prefix per enum type, so one generic widget can label them all.
String optionLabel(Object? value) {
  if (value == null) return '';
  return switch (value) {
    AbundanceRange v => v.label,
    DevelopmentStage v => 'stage.${v.name}'.tr(),
    Sex v => 'sex.${v.name}'.tr(),
    DataType v => 'data_type.${v.name}'.tr(),
    CollectionMethod v => 'method.${v.name}'.tr(),
    HabitatType v => 'habitat.${v.name}'.tr(),
    WaterBedType v => 'water_bed.${v.name}'.tr(),
    _ => value.toString(),
  };
}
