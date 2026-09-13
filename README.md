# Field trackers

Flutter apps for field surveys, built on one shared package:

- `packages/tracker_core` — map, GPS transect recording, photos, storage, backup, CSV/KML/KMZ export and import.
- `apps/bird_tracker` — Bird Tracker.
- `apps/herp_tracker` — Herp Tracker (reptiles and amphibians).

Each app is a complete Flutter project: build and deploy from its own directory (`cd apps/bird_tracker && ./build_release.sh`). Flutter is managed by fvm; run `fvm flutter pub get` once at the repo root to resolve the whole workspace.
