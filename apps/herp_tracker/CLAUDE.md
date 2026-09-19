# CLAUDE.md — Herp Tracker

The shared architecture, commands, localization and permission rules are in the root `CLAUDE.md`. This file covers only what is herp-specific.

## Domain

- **Record fields** come from the survey data dictionary ("Vrste za aplikaciju.xlsx" in this directory). `lib/domain/herp_record.dart` — `HerpRecord`: species, `observedAt` (stamped at save; both the "Datum" and "Datum posmatranja" export columns), locality, development stage, sex, count, abundance range, and the advanced fields (data type, collection method, habitat, water bed, note). The enumerated ones live in `lib/configuration/field_options.dart` as enums; the **enum `name` is what gets persisted and exported in machine payloads**, while the label always goes through `.tr()` (`optionLabel()` maps a value to its key). `AbundanceRange` labels are numeric ranges, the same in every language.
- **Automatic fields**: `observedAt` and the point's latitude/longitude/altitude/accuracy are captured silently — they deliberately have **no inputs** in the form.
- `lib/domain/herp_config.dart` — the `TrackerConfig`. `kRecordColumnKeys` is the spreadsheet's column order as `csv_header.*` keys; headers and option labels follow the app language. `herpExportValues` fills them — empty rather than absent for a blank field, so the KML balloon shows the row as "No value", which is information too. There is no legacy description parser: herp never shipped a KML without the payload.
- `lib/domain/herp_form_fields.dart` — locality, stage, sex, count + abundance, the photo strip, then an "Advanced" `ExpansionTile` (opens itself when editing a record that uses it). "Save and new" keeps the survey context (locality, habitat, method) and clears only what describes the individual animal. The locality is remembered across records in `DataService().getString(kLastLocalityKey)`.
- `lib/configuration/species.dart` — the catalog of 50 Latin names; `speciesKey` drops the dot (`Pelophylax kl. esculentus` → `species.Pelophylax kl esculentus`), `speciesLabel` translates.

## Release

Version format in `pubspec.yaml` is `X.Y.Z+N`. `./build_release.sh [--bump]` and `./deploy_ios.sh` from this directory; `ios/deploy.env` and `android/key.properties` are this app's own. iOS export uses automatic signing.

### Launcher icon and store assets

Sources live in `launcher_icon/` (outside `assets/`, so they are not bundled into the app): `app_icon.png` is the full-bleed 1024×1024 square used for iOS, the Android legacy icon and the Play listing, `app_icon_foreground.png` is the artwork alone on transparency, pre-padded to 62% of the canvas for the Android adaptive icon's safe zone. Neither may have rounded corners — iOS and Android apply their own mask, so a rounded source leaves white corners. Regenerate the platform sets with `fvm dart run flutter_launcher_icons` after changing either file. That tool does **not** touch the Android splash screen: `android/app/src/main/res/drawable-*/launch_image.png` is a separate set. `store/` holds the Play/App Store screenshot pipeline (`compose_*.py`, `brand.py`).
