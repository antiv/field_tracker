#!/bin/bash
set -e

BUMP=false
for arg in "$@"; do
    if [ "$arg" == "--bump" ]; then
        BUMP=true
    fi
done

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

if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    echo "Copying AAB to project root..."
    cp build/app/outputs/bundle/release/app-release.aab bird_tracker.aab
    echo "Success! Clean and optimized AppBundle is ready at: bird_tracker.aab"
else
    echo "Error: Build finished, but AppBundle was not found in the expected directory."
    exit 1
fi
