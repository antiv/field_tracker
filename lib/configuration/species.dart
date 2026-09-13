import 'package:easy_localization/easy_localization.dart';

/// Herpetofauna species catalog — source: "Vrste za aplikaciju.xlsx" (rows 1-50).
/// The Latin name is what gets persisted and exported; [speciesLabel] turns it
/// into the common name in the active language.
const kSpecies = [
  // Amphibia — Caudata
  'Salamandra salamandra',
  'Salamandra atra',
  'Ichthyosaura alpestris',
  'Lissotriton vulgaris',
  'Triturus cristatus',
  'Triturus dobrogicus',
  'Triturus ivanbureschi',
  'Triturus macedonicus',
  // Amphibia — Anura
  'Bombina bombina',
  'Bombina variegata',
  'Pelobates balcanicus',
  'Pelobates fuscus',
  'Bufo bufo',
  'Bufotes viridis',
  'Hyla arborea',
  'Hyla orientalis',
  'Pelophylax kl. esculentus',
  'Pelophylax lessonae',
  'Pelophylax ridibundus',
  'Rana dalmatina',
  'Rana graeca',
  'Rana temporaria',
  // Reptilia — Testudines
  'Testudo graeca',
  'Testudo hermanni',
  'Trachemys scripta',
  'Emys orbicularis',
  // Reptilia — Sauria
  'Mediodactylus kotschyi',
  'Hemidactylus turcicus',
  'Algyroides nigropunctatus',
  'Darevskia praticola',
  'Lacerta agilis',
  'Lacerta trilineata',
  'Lacerta viridis',
  'Podarcis erhardii',
  'Podarcis muralis',
  'Podarcis tauricus',
  'Zootoca vivipara',
  'Ablepharus kitaibelii',
  'Anguis colchica',
  'Anguis fragilis',
  // Reptilia — Serpentes
  'Natrix natrix',
  'Natrix tessellata',
  'Coronella austriaca',
  'Dolichophis caspius',
  'Elaphe quatuorlineata',
  'Platyceps najadum',
  'Zamenis longissimus',
  'Vipera ammodytes',
  'Vipera berus',
  'Vipera ursinii',
];

/// The `species.*` translation key for a Latin name.
///
/// easy_localization splits a key on `.` and walks the JSON as a path, so
/// `species.Pelophylax kl. esculentus` was looked up as
/// `species` → `Pelophylax kl` → ` esculentus`, found nothing, and came back
/// as the raw key — the one species in the catalog whose name carries the
/// abbreviation "kl." showed up untranslated everywhere. The dots are dropped
/// from the **key** only: [kSpecies] keeps the real name, which is what lands
/// in the database, the CSV and the KML payload.
String speciesKey(String latin) => 'species.${latin.replaceAll('.', '')}';

/// The common name for a Latin name, in the active language.
String speciesLabel(String latin) => speciesKey(latin).tr();
