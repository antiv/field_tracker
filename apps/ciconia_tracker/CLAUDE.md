# CLAUDE.md — Popis roda (ciconia_tracker)

The shared architecture, commands, localization and permission rules are in the root `CLAUDE.md`. This file covers only what is specific to the white stork nest census.

## Domain

- **One species.** `speciesCatalog: null` — the form has no species field and `NestRecord.species` is the constant `Ciconia ciconia`.
- **One nest per point.** `singleRecordPerPoint: true` — the point *is* the nest; the point sheet offers "add" only while the point has no record, the form has no "Save and new", and a second tap on the nest edits it.
- `lib/domain/nest_record.dart` — `NestRecord`: `time` (stamped at save), `count` (young in the nest), atlas `code`, `NestPosition` (where the nest sits) and `NestState` (what is in it), `place`, `municipality`, `description`. The enums are in `lib/configuration/options.dart`; the **enum `name` is persisted and exported in machine payloads**, the label goes through `.tr()` (`optionLabel`). The atlas codes are Bird Tracker's (`lib/configuration/codes.dart`, `codes.*` translations).
- **Surveyor details** — name, email, phone, typed once in the drawer ("Podaci o popisivaču", `lib/widgets/user_details_form.dart`, an `extraMenuItems` entry) and stored in preferences (`kSurveyor*Key`); `nestExportValues` puts them into every CSV row and balloon, because the census sheet wants them per row.
- `lib/domain/ciconia_config.dart` — `kRecordColumnKeys` is the census sheet's column order as `csv_header.*` keys (date, time, decimal and DMS coordinates, position, state, young, atlas code, place, municipality, note, surveyor, email, phone). No legacy description parser: the app was never published, so no old KML exists.

## Origin

Rewritten on tracker_core from the `rode` branch of the old herp_tracker repository (`ciconia_tracker`, Isar, `location` 6, no photos), which is not part of this monorepo. The `android/` and `ios/` shells are Bird Tracker's with the package, bundle id (`rs.antonijevic.ciconia_tracker` / `rs.antonijevic.ciconiaTracker`), display name ("Popis roda"), permission prose and icons changed. Version starts at `1.0.0+1`.

## Release

Not yet published. Before the first release: a Maps API key restricted to this package/bundle in `.env` (the file is a placeholder copied from Bird Tracker, whose key will not render maps here), `android/key.properties` (a keystore of its own or the shared upload key), `ios/deploy.env`, the App Store Connect app and Play listing, the privacy policy URL. Then `./build_release.sh` and `./deploy_ios.sh` from this directory like the other apps.
