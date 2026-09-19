#!/bin/bash
# Analyze and test every workspace member. A core change is only done when
# this is green for all apps.
set -e
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER="${FLUTTER:-fvm flutter}"

cd "$ROOT" && $FLUTTER pub get

for pkg in "$ROOT"/packages/* "$ROOT"/apps/*; do
  [ -f "$pkg/pubspec.yaml" ] || continue
  echo "==> $(basename "$pkg"): analyze"
  (cd "$pkg" && $FLUTTER analyze)
  if [ -d "$pkg/test" ]; then
    echo "==> $(basename "$pkg"): test"
    (cd "$pkg" && $FLUTTER test)
  fi
done
echo "All green."
