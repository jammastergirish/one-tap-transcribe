#!/usr/bin/env bash
#
# Build a PUBLIC, notarized One Tap Transcribe release: sign with Developer ID +
# Hardened Runtime, package a .dmg, notarize with Apple, and staple the ticket.
# The result opens on any Mac without Gatekeeper warnings.
#
# One-time prerequisites:
#   1. Apple Developer Program membership.
#   2. A "Developer ID Application" certificate in your login keychain
#      (Xcode → Settings → Accounts → Manage Certificates → +).
#   3. A notarytool credential profile:
#        xcrun notarytool store-credentials "OneTapNotary" \
#          --apple-id "you@example.com" --team-id "YOURTEAMID" \
#          --password "app-specific-password"   # appleid.apple.com → App-Specific Passwords
#
# Usage:
#   SIGN_ID="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE="OneTapNotary" \
#   ./release.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
: "${SIGN_ID:?set SIGN_ID to your 'Developer ID Application: …' identity (security find-identity -p codesigning -v)}"
: "${NOTARY_PROFILE:?set NOTARY_PROFILE to your notarytool keychain profile name}"

APP="$ROOT/build/OneTapTranscribe.app"
ENTITLEMENTS="$ROOT/Resources/OneTapTranscribe.entitlements"

echo "==> building app bundle"
"$ROOT/build_app.sh" release

echo "==> signing with Developer ID + Hardened Runtime"
codesign --force --deep --options runtime --timestamp \
    --sign "$SIGN_ID" \
    --entitlements "$ENTITLEMENTS" \
    "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "==> packaging .dmg"
"$ROOT/make_dmg.sh"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
DMG="$ROOT/build/OneTapTranscribe-$VERSION.dmg"

echo "==> notarizing (a few minutes)…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> stapling the notarization ticket"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> release ready"
echo "$DMG"
echo -n "SHA-256: "; shasum -a 256 "$DMG" | awk '{print $1}'
