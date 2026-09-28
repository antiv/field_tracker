#!/bin/zsh
# Drive Bird Tracker on a headless iOS simulator.
# Run from apps/bird_tracker. See SKILL.md next to this file.
#
#   sim.sh launch                 build + run (debug) in the background, wait for the VM service
#   sim.sh ss <name>              screenshot -> build/run/<name>.png, resized to POINTS (tap coords = pixel coords)
#   sim.sh tap <x> <y>            tap at points
#   sim.sh longpress <x> <y> [s]  touch down, hold (default 1s), up
#   sim.sh swipe <x1> <y1> <x2> <y2>  drag (scroll a list, grow/close a bottom sheet, pan the map)
#   sim.sh type <text>            replace the text of the FOCUSED field (tap the field first)
#   sim.sh eval <expr> [lib-uri]  evaluate Dart in the app (default lib: flutter widgets)
#   sim.sh state                  active transect's points and records, via DataService
#   sim.sh files                  exported files (Library/Caches) and media photos in the app container
#   sim.sh stop                   stop flutter run and terminate the app
set -e
SKILL=${0:A:h}
OUT=build/run
BUNDLE=rs.antonijevic.birdTracker
SCALE=${SCALE:-3}          # device pixels per point (3 on every current iPhone, 2 on iPhone SE)
mkdir -p $OUT

udid() {
  if [ -n "$UDID" ]; then echo $UDID; return; fi
  xcrun simctl list devices booted | grep -m1 -oE 'iPhone[^(]*\(([0-9A-F-]{36})\) \(Booted\)' \
    | grep -oE '[0-9A-F-]{36}' || { echo "no booted iPhone simulator: xcrun simctl boot <udid>" >&2; exit 1; }
}
U=$(udid)
vmuri() { cat $OUT/vm-uri 2>/dev/null || { echo "app not launched: sim.sh launch" >&2; exit 1; }; }

case $1 in
launch)
  # Novi Sad; location permission pre-granted so no system prompt blocks the first screen
  xcrun simctl location $U set 45.2671,19.8335
  xcrun simctl privacy $U grant location-always $BUNDLE 2>/dev/null || true
  # the old log must go first: the loop below would read the previous run's VM URI
  # before the background shell gets to truncate the file
  rm -f $OUT/vm-uri $OUT/flutter.log
  nohup fvm flutter run -d $U > $OUT/flutter.log 2>&1 < /dev/null &
  echo $! > $OUT/flutter.pid
  echo "flutter run pid $!, log $OUT/flutter.log (first build takes a few minutes)"
  for i in {1..600}; do
    uri=$(grep -oE 'http://127\.0\.0\.1:[0-9]+/[^/ ]+/' $OUT/flutter.log | head -1)
    if [ -n "$uri" ]; then echo "ws${uri#http}ws" > $OUT/vm-uri; echo "running; VM $(cat $OUT/vm-uri)"; exit 0; fi
    if ! kill -0 $(cat $OUT/flutter.pid) 2>/dev/null; then tail -30 $OUT/flutter.log; exit 1; fi
    sleep 1
  done
  echo "timed out"; tail -30 $OUT/flutter.log; exit 1 ;;
ss)
  f=$OUT/${2:-screen}.png
  sleep ${WAIT:-1}
  xcrun simctl io $U screenshot $f >/dev/null 2>&1
  w=$(sips -g pixelWidth $f | awk '/pixelWidth/{print $2}'); h=$(sips -g pixelHeight $f | awk '/pixelHeight/{print $2}')
  sips -z $((h / SCALE)) $((w / SCALE)) $f >/dev/null
  echo $f ;;
tap)       axe tap -x $2 -y $3 --udid $U ;;
swipe)     axe swipe --start-x $2 --start-y $3 --end-x $4 --end-y $5 --duration 0.6 --udid $U >/dev/null ;;
longpress) axe touch -x $2 -y $3 --down --udid $U >/dev/null; sleep ${4:-1}; axe touch -x $2 -y $3 --up --udid $U >/dev/null ;;
type)
  t=${2//\'/\\\'}
  python3 $SKILL/vm.py $(vmuri) "FocusManager.instance.primaryFocus!.context!.findAncestorStateOfType<EditableTextState>()!.widget.controller.value = TextEditingValue(text: '$t', selection: TextSelection.collapsed(offset: ${#2}))" >/dev/null
  echo "typed: $2" ;;
eval)      python3 $SKILL/vm.py $(vmuri) "$2" ${3:-} ;;
state)
  python3 $SKILL/vm.py $(vmuri) \
    "DataService().transect == null ? 'no active transect' : 'transect \${DataService().transect!.id} \"\${DataService().transect!.name}\": ' + (DataService().transect!.markers ?? []).map((m) => 'point \${m.id} photos=\${m.photos} records=[\${(m.records ?? []).map((r) => '\${r.species} \${r.photos}').join(\"; \")}]').join(' | ')" \
    package:tracker_core/service/data_service.dart ;;
files)
  D=$(xcrun simctl get_app_container $U $BUNDLE data)
  echo "== exports ($D/Library/Caches)"; ls -lt "$D/Library/Caches" | grep -vE 'com\.apple|CCTClearcut|rs\.antonijevic|^total' || true
  echo "== media"; ls "$D/Documents/media" 2>/dev/null || true ;;
stop)
  [ -f $OUT/flutter.pid ] && kill $(cat $OUT/flutter.pid) 2>/dev/null || true
  xcrun simctl terminate $U $BUNDLE 2>/dev/null || true
  rm -f $OUT/vm-uri $OUT/flutter.pid; echo stopped ;;
*) sed -n '2,16p' $0; exit 1 ;;
esac
