#!/usr/bin/env bash
#
# Package build/OneTapTranscribe.app into a distributable .dmg and print its
# SHA-256. Run ./build_app.sh first.
#
# NOTE: For a public download that opens without Gatekeeper warnings, the .app
# must be signed with an Apple "Developer ID Application" certificate and
# notarized BEFORE running this (see README → Publishing). This script only
# assembles the disk image.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/build/OneTapTranscribe.app"

if [ ! -d "$APP" ]; then
    echo "error: $APP not found — run ./build_app.sh release first." >&2
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$ROOT/build/OneTapTranscribe-$VERSION.dmg"
STAGING="$(mktemp -d)"

cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"   # drag-to-install target

rm -f "$DMG"
hdiutil create -volname "One Tap Transcribe" \
    -srcfolder "$STAGING" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGING"

# Also emit a version-less copy so the site's permanent one-click link
# (…/releases/latest/download/OneTapTranscribe.dmg) always resolves. Upload BOTH
# assets to each GitHub Release.
cp "$DMG" "$ROOT/build/OneTapTranscribe.dmg"

echo "Created $DMG"
echo "        $ROOT/build/OneTapTranscribe.dmg (version-less copy for the 'latest' link)"
echo -n "SHA-256: "
shasum -a 256 "$DMG" | awk '{print $1}'
