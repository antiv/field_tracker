# Herp Tracker

Herp Tracker is a Flutter app (Android + iOS) for field surveys of reptiles and amphibians. You
record a transect (survey route) on a Google Map, drop a point wherever you find an animal, and
attach one observation record per finding — species, locality, development stage, sex, number of
individuals, habitat and more. Recorded surveys can be exported and shared as CSV or KML, and the
whole database can be backed up to a JSON file.

The species catalog covers the 50 reptile and amphibian species of Serbia and the surrounding
region, with common names in English and Serbian.

## Observation record

Fields follow the survey data dictionary. GPS values and the observation timestamp are captured
automatically and have no input fields.

| Field | Source |
|---|---|
| Species | searchable list of 50 species (Latin + common name) |
| Date / Observation date | automatic, at the moment the record is saved |
| LAT, LONG, Altitude, GPS accuracy | automatic, from the GPS fix of the point |
| Locality | free text, pre-filled with the last used value |
| Development stage | eggs, tadpoles, juvenile, adult |
| Sex | M, F, both |
| Exact number of individuals | number |
| Abundance range | 2-5 … 1001-10000 |
| Data type | Advanced — collecting, observation, photographing, listening, potentially present |
| Collection method | Advanced — hand capture, traps, echolocation, observation, other |
| Habitat type | Advanced — 36 values |
| Water habitat bed type | Advanced — 9 values |
| Note | Advanced — free text |

Advanced fields are collapsed by default and only expand when needed.

## Export

- **CSV** — one row per record, column order matching the survey spreadsheet; headers and option
  labels follow the app language (English / Serbian). UTF-8 with BOM, so Excel opens it correctly.
- **KML** — one placemark per point plus the recorded route. The full records travel in the
  placemark's `ExtendedData`, so a KML exported by the app can be re-imported without losing a
  single field.
- **JSON backup / restore** — the entire database.

## Development

Flutter is managed by **fvm** — use `fvm flutter ...`:

```bash
fvm flutter pub get
fvm flutter run
fvm flutter analyze
```

Runtime configuration (Google Maps key, privacy policy URL) lives in a `.env` file at the repo
root, which is not in git. See `CLAUDE.md` for the full list of untracked configuration files and
for the release build scripts (`build_release.sh` for Android, `deploy_ios.sh` for iOS).

## License

This project is licensed under the [MIT License](LICENSE).
