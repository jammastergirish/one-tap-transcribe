#!/usr/bin/env bash
#
# Build OneTapTranscribe and wrap it into a proper .app bundle so macOS will
# grant it Microphone + Accessibility permissions and hide it from the Dock.
#
# Usage:
#   ./build_app.sh [debug|release]     # build the bundle
#   ./build_app.sh release run         # build then launch
#
set -euo pipefail

APP_NAME="OneTapTranscribe"
BUNDLE_ID="com.onetap.transcribe"
ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${1:-release}"
DO_RUN="${2:-}"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
APP="$ROOT/build/$APP_NAME.app"
CONTENTS="$APP/Contents"

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/$APP_NAME" "$CONTENTS/MacOS/$APP_NAME"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

# Ship any bundled Swift package resources (e.g. WhisperKit) next to the binary.
if compgen -G "$BIN_DIR/*.bundle" > /dev/null; then
    cp -R "$BIN_DIR"/*.bundle "$CONTENTS/Resources/" 2>/dev/null || true
fi

echo "==> code signing (ad-hoc)"
codesign --force --deep --sign - \
    --identifier "$BUNDLE_ID" \
    --entitlements "$ROOT/Resources/$APP_NAME.entitlements" \
    "$APP"

echo "==> done: $APP"

if [[ "$DO_RUN" == "run" ]]; then
    echo "==> launching"
    open "$APP"
fi
