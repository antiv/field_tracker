#!/bin/bash
#
# build_release.sh — obfuscated Android AppBundle, optionally uploaded to Google Play.
#
#   ./build_release.sh                  # build only, .aab lands in the app directory
#   ./build_release.sh --bump           # bump patch+build in pubspec first
#   ./build_release.sh --upload         # ...and push the .aab to the Play internal track
#
# --upload reads android/deploy.env (see android/deploy.env.example) and hands the
# bundle to tool/play_upload.py. Play cannot take an app's *first* bundle over the
# API — that one goes through the console by hand, every later one can go this way.
#
set -e

# Runs from the app directory wherever it was invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
PLAY_UPLOAD="$SCRIPT_DIR/../../tool/play_upload.py"
ENV_FILE="android/deploy.env"

BUMP=false
UPLOAD=false
for arg in "$@"; do
    case "$arg" in
        --bump)   BUMP=true ;;
        --upload) UPLOAD=true ;;
        -h|--help)
            sed -n '5,7p' "$0" | sed 's/^#[[:space:]]\{0,1\}//'
            exit 0 ;;
        *)
            echo "Unknown argument: $arg" >&2
            echo "Allowed: --bump | --upload | --help" >&2
            exit 64 ;;
    esac
done

# Everything the upload needs is checked up front, before the bump and the build.
if [ "$UPLOAD" = true ]; then
    if [ ! -f "$ENV_FILE" ]; then
        echo "Missing $ENV_FILE — copy android/deploy.env.example and fill it in." >&2
        exit 1
    fi
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    if [ -z "${PLAY_SERVICE_ACCOUNT_JSON:-}" ]; then
        echo "PLAY_SERVICE_ACCOUNT_JSON is not set in $ENV_FILE" >&2
        exit 1
    fi
    if [ ! -f "$PLAY_SERVICE_ACCOUNT_JSON" ]; then
        echo "Service account key not found at PLAY_SERVICE_ACCOUNT_JSON=$PLAY_SERVICE_ACCOUNT_JSON" >&2
        exit 1
    fi
    if ! python3 -c 'import googleapiclient, google.oauth2' 2>/dev/null; then
        echo "python3 lacks the Play API client: pip3 install google-api-python-client google-auth" >&2
        exit 1
    fi
    # The applicationId is the Play package name.
    PACKAGE="$(grep -E 'applicationId[[:space:]]*=' android/app/build.gradle.kts | head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
    if [ -z "$PACKAGE" ]; then
        echo "Cannot read applicationId from android/app/build.gradle.kts" >&2
        exit 1
    fi
fi

if [ "$BUMP" = true ]; then
    echo "Bumping version..."
    
    # Extract current version
    CURRENT_VERSION=$(grep '^version: ' pubspec.yaml | awk '{print $2}')
    echo "Current version: $CURRENT_VERSION"
    
    # Ensure version follows the expected X.Y.Z+N format
    if [[ ! "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
        echo "Error: Version format in pubspec.yaml must be X.Y.Z+N (e.g., 1.0.0+9)"
        exit 1
    fi

    # Parse the version
    BASE_VERSION=$(echo "$CURRENT_VERSION" | cut -d+ -f1)
    BUILD_NUMBER=$(echo "$CURRENT_VERSION" | cut -d+ -f2)
    
    MAJOR=$(echo "$BASE_VERSION" | cut -d. -f1)
    MINOR=$(echo "$BASE_VERSION" | cut -d. -f2)
    PATCH=$(echo "$BASE_VERSION" | cut -d. -f3)
    
    # Bump Patch and Build Number
    PATCH=$((PATCH + 1))
    BUILD_NUMBER=$((BUILD_NUMBER + 1))
    
    NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}+${BUILD_NUMBER}"
    echo "New version: $NEW_VERSION"
    
    # Update pubspec.yaml safely
    sed -i '' "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml
else
    echo "Skipping version bump. Pass --bump to update the version."
fi

echo "Cleaning project..."
fvm flutter clean

echo "Getting dependencies..."
fvm flutter pub get

echo "Building Android AppBundle..."
# I added obfuscation options to reduce the AppBundle size further as we discussed earlier.
fvm flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols

# Named after the app, so the same script serves every tracker.
AAB_NAME="$(grep '^name: ' pubspec.yaml | awk '{print $2}').aab"

if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    echo "Copying AAB to project root..."
    cp build/app/outputs/bundle/release/app-release.aab "$AAB_NAME"
    echo "Success! Clean and optimized AppBundle is ready at: $AAB_NAME"
else
    echo "Error: Build finished, but AppBundle was not found in the expected directory."
    exit 1
fi

if [ "$UPLOAD" = true ]; then
    TRACK="${PLAY_TRACK:-internal}"
    echo "Uploading $AAB_NAME to Google Play ($PACKAGE, $TRACK track)..."
    python3 "$PLAY_UPLOAD" "$AAB_NAME" "$PACKAGE" --track "$TRACK" --key "$PLAY_SERVICE_ACCOUNT_JSON"
    echo "Play processes the bundle for a few minutes; then it shows under Testing → the $TRACK track."
fi
