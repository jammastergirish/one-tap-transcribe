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
cp "$ROOT/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns" 2>/dev/null || true

# Ship any bundled Swift package resources (e.g. WhisperKit) next to the binary.
if compgen -G "$BIN_DIR/*.bundle" > /dev/null; then
    cp -R "$BIN_DIR"/*.bundle "$CONTENTS/Resources/" 2>/dev/null || true
fi

# Prefer the stable self-signed identity (from ./setup_signing.sh) so the
# designated requirement is cert-based and macOS keeps Accessibility across
# rebuilds. Fall back to ad-hoc if it isn't set up.
SIGN_ID="One Tap Local Signing"
SIGN_KC="$HOME/Library/Keychains/onetap-signing.keychain-db"
if [ -f "$SIGN_KC" ] && security find-identity -p codesigning "$SIGN_KC" 2>/dev/null | grep -q "$SIGN_ID"; then
    echo "==> code signing (stable identity: $SIGN_ID)"
    security unlock-keychain -p onetap-local "$SIGN_KC" 2>/dev/null || true
    codesign --force --deep --sign "$SIGN_ID" --keychain "$SIGN_KC" \
        --identifier "$BUNDLE_ID" \
        --entitlements "$ROOT/Resources/$APP_NAME.entitlements" \
        "$APP"
else
    echo "==> code signing (ad-hoc — run ./setup_signing.sh once to stop re-granting)"
    codesign --force --deep --sign - \
        --identifier "$BUNDLE_ID" \
        --entitlements "$ROOT/Resources/$APP_NAME.entitlements" \
        "$APP"
fi

echo "==> done: $APP"

if [[ "$DO_RUN" == "run" ]]; then
    echo "==> launching"
    open "$APP"
fi
