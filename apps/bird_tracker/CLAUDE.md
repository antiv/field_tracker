# CLAUDE.md — Bird Tracker

The shared architecture, commands, localization and permission rules are in the root `CLAUDE.md`. This file covers only what is bird-specific.

## Domain

- `lib/domain/bird_record.dart` — `BirdRecord`: species, `time` (hh:mm:ss, stamped at save), `count`, atlas breeding `code`, `description` (behaviour), `Stratification` (g/s/d) and `Direction` (16 compass points). `summary` is the exact line older KML exports carried in their `<description>`; `fromSpeciesString`/`listFromDescription` read it back, and the config passes that as `recordsFromLegacyDescription` — every KML already shared with a colleague still imports.
- `lib/domain/bird_config.dart` — the `TrackerConfig`. The CSV columns are **fixed, in English, in the order they have always had** (`birdExportColumns`); sheets built on the export expect them, so they do not follow the app language the way herp's do. The core appends transect, point and photos after them. `Latitude(DMS)`/`Longitude(DMS)` use `convertLatLng` from the core.
- `lib/domain/bird_form_fields.dart` — count, atlas code (`CodePicker`), compass (`WorldSidePicker`, `lib/widgets/`) next to stratification (`BlockEnumRadio`, the bordered block — the core's compact `EnumRadio` would not sit well beside a 160 px compass), behaviour note, then the photo strip.
- `lib/configuration/species.dart` — the catalog of Latin names and `speciesTranslationKey` (dot → underscore, so `Anas sp.` is `species.Anas sp_` in the translations). `lib/configuration/codes.dart` — the atlas codes; their descriptions are the `codes.*` translation block.

## Release

Version format in `pubspec.yaml` is `X.Y.Z+N`. `./build_release.sh [--bump]` and `./deploy_ios.sh` from this directory; `ios/deploy.env` and `android/key.properties` are this app's own. iOS export uses a manual provisioning profile ("BirdTracker AppStore").

`Birds_of_Serbia.pdf` / `Birds_of_Serbia_species.xlsx` are the catalog's sources; `screenshots/` the store listing.
