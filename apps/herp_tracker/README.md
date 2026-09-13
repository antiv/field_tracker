# Herp Tracker

Herp Tracker is a Flutter app (Android + iOS) for field surveys of reptiles and amphibians (herpetofauna). You
record a transect (survey route) on a Google Map, drop a point wherever you find an animal, and
attach one observation record per finding — species, locality, development stage, sex, number of
individuals, habitat and more. A record can carry several photos, taken on the spot or picked from
the gallery. Recorded surveys can be exported and shared as CSV, KML or KMZ, and the whole
database can be backed up to a single archive.

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
| Photos | any number, from the camera or the gallery |

Advanced fields are collapsed by default and only expand when needed.

## Photos

Tap the camera or the gallery button on a record to attach as many photos as the finding needs.
Every photo is kept in two places: inside the app, where the record and the exports read it, and in
a **Herp Tracker** album in the device gallery, so the field photos are there in Photos / Gallery
like any others. A photo picked from the gallery is copied in rather than linked, so deleting the
original later never empties a record.

Photos are only ever stored on the device — nothing is uploaded anywhere. They leave the phone only
when you share an export or a backup yourself.

## Export

- **CSV** — one row per record, column order matching the survey spreadsheet; headers and option
  labels follow the app language (English / Serbian). UTF-8 with BOM, so Excel opens it correctly.
  Photo file names are exported in their own column.
- **KML / KMZ** — one placemark per point plus the recorded route. The full records travel in the
  placemark's `ExtendedData`, so an export from the app can be re-imported without losing a single
  field. When a survey has photos the export is a **KMZ** with the images bundled in, and Google
  Earth shows them in the placemark balloon; without photos it stays a plain `.kml`. Both can be
  imported back — the import accepts either, and tells them apart by content rather than by file name.
- **Backup / restore** — the entire database as a `.zip`: the records as JSON plus the record
  photos. Restoring replaces everything that is currently in the app. Older plain `.json` backups
  can still be restored, without their photos.

## Development

Flutter is managed by **fvm** — use `fvm flutter ...`:

```bash
fvm flutter pub get
fvm flutter run
fvm flutter analyze
fvm flutter test
```

Runtime configuration (Google Maps key, privacy policy URL) lives in a `.env` file at the repo
root, which is not in git. See `CLAUDE.md` for the full list of untracked configuration files and
for the release build scripts (`build_release.sh` for Android, `deploy_ios.sh` for iOS).

## License

This project is licensed under the [MIT License](LICENSE).
