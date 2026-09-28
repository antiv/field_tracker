#!/bin/bash
#
# promote.sh — put the tested release of one app into production on both stores.
#
#   tool/promote.sh <app> --dry-run                       # check both stores, change nothing
#   tool/promote.sh <app> --notes-en "..." --notes-sr "..."
#
#   <app>                bird_tracker | herp_tracker | ciconia_tracker
#   --android | --ios    only one store (default: both)
#   --rollout F          Play staged rollout, 0 < F < 1 (default: everyone)
#   --manual-release     App Store: wait for "Release" after approval (default: live on approval)
#   --notes-en / --notes-sr   What's New; Play en-US / sr, App Store en-US / hr
#
# The version is the one in apps/<app>/pubspec.yaml (X.Y.Z+N) — the one the last
# build_release.sh --bump / deploy_ios.sh --no-bump pair uploaded. Android: the
# versionCode N moves from the internal track to production (tool/play_promote.py).
# iOS: build N becomes App Store version X.Y.Z and is submitted for review
# (tool/asc_submit.py). Both stores review before the release is live.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-}"
[[ -n "$APP" && "$APP" != -* ]] || { sed -n '5,13p' "$0" | sed 's/^#[[:space:]]\{0,1\}//'; exit 64; }
shift
DIR="$ROOT/apps/$APP"
[[ -d "$DIR" ]] || { echo "No app at $DIR" >&2; exit 1; }

ANDROID=true; IOS=true; DRY=(); ROLLOUT=(); MANUAL=(); NOTES_EN=""; NOTES_SR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --android)        IOS=false ;;
    --ios)            ANDROID=false ;;
    --dry-run)        DRY=(--dry-run) ;;
    --rollout)        ROLLOUT=(--rollout "$2"); shift ;;
    --manual-release) MANUAL=(--manual-release) ;;
    --notes-en)       NOTES_EN="$2"; shift ;;
    --notes-sr)       NOTES_SR="$2"; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 64 ;;
  esac
  shift
done

version="$(grep -m1 -E '^version:' "$DIR/pubspec.yaml" | sed -E 's/^version:[[:space:]]*//' | tr -d '[:space:]')"
name="${version%%+*}"; code="${version#*+}"
[[ "$code" != "$version" ]] || { echo "No +build in version '$version'" >&2; exit 1; }
echo "== $APP $name ($code)"

if $ANDROID; then
  package="$(grep -m1 -oE 'applicationId = "[^"]+"' "$DIR/android/app/build.gradle.kts" | cut -d'"' -f2)"
  # shellcheck disable=SC1091
  source "$DIR/android/deploy.env"
  notes=()
  [[ -n "$NOTES_EN" ]] && notes+=(--notes "en-US=$NOTES_EN")
  [[ -n "$NOTES_SR" ]] && notes+=(--notes "sr=$NOTES_SR")
  echo "-- Google Play"
  PLAY_SERVICE_ACCOUNT_JSON="$PLAY_SERVICE_ACCOUNT_JSON" python3 "$ROOT/tool/play_promote.py" \
    "$package" "$code" ${ROLLOUT[@]+"${ROLLOUT[@]}"} ${notes[@]+"${notes[@]}"} ${DRY[@]+"${DRY[@]}"}
fi

if $IOS; then
  bundle="$(grep -m1 -oE 'PRODUCT_BUNDLE_IDENTIFIER = rs\.antonijevic\.[A-Za-z]+;' \
    "$DIR/ios/Runner.xcodeproj/project.pbxproj" | sed -E 's/.* = (.*);/\1/')"
  # shellcheck disable=SC1091
  source "$DIR/ios/deploy.env"
  notes=()
  [[ -n "$NOTES_EN" ]] && notes+=(--notes "en-US=$NOTES_EN")
  # the App Store has no Serbian; a listing in Croatian stands in for it
  [[ -n "$NOTES_SR" ]] && notes+=(--notes "hr=$NOTES_SR")
  echo "-- App Store"
  ASC_KEY_ID="$ASC_KEY_ID" ASC_ISSUER_ID="$ASC_ISSUER_ID" ASC_KEY_PATH="$ASC_KEY_PATH" \
    python3 "$ROOT/tool/asc_submit.py" "$bundle" "$name" "$code" \
    ${MANUAL[@]+"${MANUAL[@]}"} ${notes[@]+"${notes[@]}"} ${DRY[@]+"${DRY[@]}"}
fi
