# tracker_core

Everything the field tracker apps share: the map screen, GPS transect recording, photos, sembast storage, zip backups, CSV/KML/KMZ export and import, the app shell and its translations.

An app supplies a `TrackerConfig` — branding plus its record type, species catalog, export columns and form fields — and calls `runTrackerApp(config)`.
