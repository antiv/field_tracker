---
name: run-bird-tracker
description: Run, launch, drive, test or screenshot Bird Tracker (apps/bird_tracker) on a headless iOS simulator — tap buttons, type into fields, read the active transect, list exported CSV/KML/KMZ/zip files. Use to check a tracker_core or bird_tracker change in the real app, visually or end to end.
---

# Run Bird Tracker on the iOS simulator

Bird Tracker is a Flutter app (map + GPS transects, points with bird records, photos, CSV/KML/KMZ export). The agent drives it with **`sim.sh`** next to this file: `flutter run` in the background, taps through [AXe](https://github.com/cameroncooke/AXe), screenshots through `simctl`, text entry and state inspection through the Dart VM service (`vm.py`).

All paths are relative to `apps/bird_tracker/`. Artifacts (screenshots, `flutter.log`, the VM URI) land in `build/run/` (gitignored).

## Prerequisites (macOS, Xcode, one-time)

```bash
brew install cameroncooke/axe/axe          # tap / touch on a simulator with no window
python3 -c "import websocket"              # websocket-client, used by vm.py (pip3 install websocket-client)
xcrun simctl list devices booted           # need a booted iPhone; else: xcrun simctl boot <udid>
```

`apps/bird_tracker/.env` must exist (the app crashes at start without it). Flutter comes from fvm (`fvm flutter`).

## Run (agent path)

```bash
D=.claude/skills/run-bird-tracker/sim.sh
$D launch                 # build + run debug, returns when the VM service is up (~40 s warm, minutes cold)
$D ss home                # -> build/run/home.png, sized in POINTS: pixel coords in the image = tap coords
$D tap 357 225            # start transect (green walker button)
$D tap 357 292            # add point -> "Add Species" form
$D tap 200 158; sleep 0.8; $D type "Parus"    # focus the species field, then set its text
$D tap 120 378            # pick a suggestion (read its position off a screenshot first)
$D tap 330 733            # Save
$D state                  # transect 3 "null": point 0 photos=[] records=[Parus ater []]
$D longpress 200 545      # long-press a row in Saved tracks -> selection mode
$D swipe 200 700 200 350  # push a sheet's list up: the sheet grows to 92 %
$D files                  # exports in Library/Caches + Documents/media
$D eval "DataService().transect?.markers?.length.toString()" package:tracker_core/service/data_service.dart   # "null" with no transect on the map
$D stop
```

Always **look at the screenshot** (Read the png) before the next tap — coordinates below are for iPhone 16 Pro (402×874 pt) and shift with any layout change.

Landmarks on iPhone 16 Pro, English UI (Pause and the CSV / KML footer buttons were read off screenshots; the rest were tapped):

| What | x y |
|---|---|
| Drawer (bird logo) | 28 90 |
| My location / Start-stop transect / Add point | 357 160 / 357 225 / 357 292 |
| While recording, after tapping the red button: Pause / Stop | 357 290 / 357 348 |
| Transect-name dialog Confirm | 265 518 |
| Drawer → Saved tracks (history sheet) | 107 292 |
| Form: species field / Save and new / Save | 200 158 / 200 733 / 330 733 |
| Form: Gallery (photo picker; Add is at 369 100) | 128 657 |
| History selection footer: CSV / KML / CSV+KML / Delete | 72 755 / 200 755 / 329 755 / 200 807 |
| Share sheet close (×) | 372 438 |

## Run (human path)

`cd apps/bird_tracker && fvm flutter run -d <udid>` — but this Xcode install has **no Simulator.app**, so there is no window to look at; use the agent path.

## Test

```bash
cd ../.. && tool/check_all.sh     # analyze + test, core and all three apps
```

## Gotchas

- **No Simulator.app** in `/Applications/Xcode.app` here: simulators run headless, so `cliclick`/AppleScript cannot click anything. AXe talks to the device directly.
- **Typing does not work**: `axe type` / `axe key` (HID keyboard) and `simctl pbcopy` (the pasteboard stays empty, `pbpaste` returns nothing) never reach a Flutter text field. `sim.sh type` instead sets the focused `EditableText`'s controller through the VM service, which fires `onChanged`, so the species autocomplete opens as if typed. Tap the field first; `type` needs a primary focus.
- **VM `evaluate` compiles in a library's scope.** Default is `package:flutter/src/widgets/editable_text.dart`; for `DataService()` pass `package:tracker_core/service/data_service.dart`. A `void` expression followed by `.toString()` is an "Expression compilation error" — evaluate an assignment or a value instead.
- A tap on an already focused field shows iOS's "Select All / Scan Text" bubble over the field label. It is the simulator's edit menu, not an app bug; it goes away on the next tap elsewhere.
- Dialog buttons move with the dialog's height: the delete dialog **with** the photos checkbox has Yes at 301 540, **without** it at 301 485. A tap outside dismisses the dialog silently, and nothing happens — screenshot first.
- The first gallery pick shows the iOS photo-library permission alert (Allow Full Access at 201 619); the location permission is pre-granted by `launch`, the photo one is not.
- Bottom sheets (point, Current track, Saved tracks) open at 56 % and grow when their list is pushed up. Pushing down past 56 % **closes** the sheet, and the next swipes pan the map — swipe down once, screenshot, then decide.
- Every `flutter run` reinstall gives the app a **new container path** — `sim.sh files` resolves it each time, don't cache it.
- Export files pile up in `Library/Caches` from earlier runs; `files` sorts newest first.
- `flutter run` is started with `nohup … < /dev/null`, so it survives the shell that launched it; `stop` kills it by the pid in `build/run/flutter.pid`. There is no hot reload from the agent path — `stop` + `launch` after a code change.
- `SCALE=2 sim.sh ss …` on an iPhone SE (2× screen); every other current iPhone is 3×. `UDID=<udid>` picks a device when several are booted.

## Troubleshooting

- `app not launched: sim.sh launch` — `build/run/vm-uri` is missing; run `launch` (or it died: see `build/run/flutter.log`).
- `no booted iPhone simulator` — `xcrun simctl boot <udid>` (list with `xcrun simctl list devices available`).
- `library not loaded: …` from `eval` — the library URI is wrong or not imported by the app; tracker_core libs are `package:tracker_core/<path under lib>`.
