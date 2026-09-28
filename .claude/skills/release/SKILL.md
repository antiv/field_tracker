---
name: release
description: Build and deploy (release, publish, upload) the tracker apps — Bird Tracker, Herp Tracker, Ciconia — to Google Play (internal track) and App Store Connect / TestFlight. Use when asked to "build and deploy", "release", "push a new version", "upload to Play / TestFlight" for one or more apps.
---

# Release the tracker apps (Android + iOS)

Each app is released from its **own directory** with its own scripts; `tracker_core` has no version. One release of one app = **Android first with the bump, then iOS without a bump**, so both stores get the same `X.Y.Z+N`. With several apps, finish one app completely before starting the next — never run two builds at once (they share the workspace `pubspec.lock`, the Flutter tool lock and Xcode's DerivedData).

Paths are relative to the repo root. `$LOGS` is any directory **outside** `apps/<app>/build/` — `build_release.sh` starts with `flutter clean`, which deletes `build/` and anything logged there.

## Per app

```bash
cd apps/<app>                                  # bird_tracker | herp_tracker | ciconia_tracker
./build_release.sh --bump --upload > $LOGS/<app>_android.log 2>&1; echo exit=$?
grep -m1 '^version' pubspec.yaml               # the version both stores now carry
./deploy_ios.sh --no-bump > $LOGS/<app>_ios.log 2>&1; echo exit=$?
```

- Android (~2–4 min): bumps patch + build number in `pubspec.yaml`, builds the obfuscated `.aab` (copied to `apps/<app>/<app>.aab`, gitignored) and uploads it to the Play **internal** track. Success line: `✓ versionCode N is on the 'internal' track of rs.antonijevic.<app>`.
- iOS (~6–9 min — run it in the background and wait on `exit=`): archive, signed export, `altool` upload. Success lines: `UPLOAD SUCCEEDED with no errors` and `✓ Otpremljeno (X.Y.Z+N)`.
- Check the tail of each log, not just the exit code, and report the version, the Play versionCode and the iOS delivery.

Then commit the two bumped `pubspec.yaml` files: a release builds from the working tree, so whatever is uncommitted at that moment is what shipped — say so if there were uncommitted changes.

## Preconditions (checked by the scripts, but check first to fail fast)

```bash
ls apps/<app>/.env apps/<app>/android/key.properties apps/<app>/android/deploy.env apps/<app>/ios/deploy.env
```

`tool/check_all.sh` should be green before a release. Uploads are outward-facing and cannot be taken back (a versionCode / build number is burned once uploaded): run them only when the user asked for a release.

## Gotchas

- The Play API cannot make an app's **first** upload — `ciconia_tracker` still needs its first bundle through the Play Console by hand (`build_release.sh --bump` without `--upload`, then upload `ciconia_tracker.aab` manually).
- `deploy_ios.sh` without flags **bumps again** — after the Android bump always pass `--no-bump`, or the stores end up on different versions.
- Harmless noise in the iOS log: `DVTDeveloperAccountManager: Failed to load credentials … missing Xcode-Token` (signing uses the App Store Connect API key, not the Xcode account) and the "Run script build phase … will be run during every build" notes.
- Harmless noise in the Android log: the KGP warning for the `location` plugin and "unobfuscated DWARF debugging information" (AGP strips it).
- Builds take the processing time of the stores on top: Play shows the bundle under Testing → internal after a few minutes, App Store Connect / TestFlight after 5–30 min.
