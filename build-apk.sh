#!/usr/bin/env bash
# Build the audiobookshelf APK inside a Podman container and optionally install it.
# Usage:
#   ./build-apk.sh            # build only
#   ./build-apk.sh --install  # build + adb install to connected device
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="audiobookshelf-builder"
APK_REL="android/app/build/outputs/apk/debug/app-debug.apk"
APK_ABS="$SCRIPT_DIR/$APK_REL"

cd "$SCRIPT_DIR"

echo "==> Building container image (cached after first run)..."
podman build -f Dockerfile.build -t "$IMAGE" .

mkdir -p "$HOME/.android"
echo "==> Running build inside container..."
podman run --rm \
  -v "$SCRIPT_DIR:/app:Z" \
  -v "$HOME/.gradle:/root/.gradle:Z" \
  -v "$HOME/.npm:/root/.npm:Z" \
  -v "$HOME/.android:/root/.android:Z" \
  "$IMAGE" \
  bash -c "
    set -euo pipefail
    npm ci
    npm run generate
    npx cap sync android
    echo \"sdk.dir=\$ANDROID_HOME\" > android/local.properties
    ./android/gradlew assembleDebug -p android --no-daemon
  "

echo ""
echo "==> Build complete!"
echo "    APK: $APK_ABS"

if [ "${1:-}" = "--install" ]; then
  echo ""
  echo "==> Installing to connected device via adb..."
  adb install -r "$APK_ABS"
  echo "==> Done."
fi
