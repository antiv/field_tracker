# CLAUDE.md — Bird Tracker

The shared architecture, commands, localization and permission rules are in the root `CLAUDE.md`. This file covers only what is bird-specific.

## Domain

- `lib/domain/bird_record.dart` — `BirdRecord`: species, `time` (hh:mm:ss, stamped at save), `count`, atlas breeding `code`, `description` (the "Comment" / "Napomena" field — its CSV column used to be `Behavior`), `Stratification` (g/s/d, "Visina" in Serbian; none until the surveyor picks one, and then an empty cell in the export — it used to default to `d`), `direction` — the **flight** direction (`Direction`, 16 compass points) — and where the bird was spotted from the point: `distance` (metres as typed, or one of `kDistanceOptions` `<50` / `50-100` / `>100`, hence a string) and `sightingDirection` (also a `Direction`, but a different thing from the flight direction — keep them apart; its dropdown offers only the 8 main points, `!isSub()`, plus whatever finer value an existing record already carries). `summary` is `<species> <count> <time>`, the record's line in the KML description. Older KML exports carried a longer line there (`species: count, code, time, strat, dir; comment`), and only for files without the payload; `fromSpeciesString`/`listFromDescription` still read that one back, and the config passes that as `recordsFromLegacyDescription` — every KML already shared with a colleague still imports.
- `lib/domain/bird_config.dart` — the `TrackerConfig`. The CSV columns are `kBirdColumnKeys` (`csv_header.*` in the app's translations), so headers follow the app language like the core's own — they used to be fixed English, and a Serbian export mixed the two. Order, as the survey sheet wants it: species, date, time (from - to), time, lat, lon, lat/lon DMS, count, distance, sighting direction, comment, stratification, flight direction, code. The core puts the point number first and appends transect and photos after them; `species_form_test` checks the whole header in both languages. `Latitude(DMS)`/`Longitude(DMS)` use `convertLatLng` from the core.
- `lib/domain/bird_form_fields.dart` — count, atlas code (`CodePicker`), compass (`WorldSidePicker`, `lib/widgets/`) next to stratification (`BlockEnumRadio`, the bordered block — the core's compact `EnumRadio` would not sit well beside the compass; the picker is about 180 px square, kept small so the form fits one screen), distance (text field with a range menu) and sighting direction (`OptionPicker`), comment, then the photo strip.
- `lib/configuration/species.dart` — the catalog of Latin names and `speciesTranslationKey` (dot → underscore, so `Anas sp.` is `species.Anas sp_` in the translations). `lib/configuration/codes.dart` — the atlas codes; their descriptions are the `codes.*` translation block.

## Release

Version format in `pubspec.yaml` is `X.Y.Z+N`. `./build_release.sh [--bump]` and `./deploy_ios.sh` from this directory; `ios/deploy.env` and `android/key.properties` are this app's own. iOS export uses a manual provisioning profile ("BirdTracker AppStore").

`Birds_of_Serbia.pdf` / `Birds_of_Serbia_species.xlsx` are the catalog's sources; `screenshots/` the store listing.
