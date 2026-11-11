#!/usr/bin/env bash
#
# build_app.sh, make_dmg.sh and release.sh are links to this file. It asks
# SwiftPM where the GraphiteEmber package is checked out and runs the script of
# the same name from its Scripts/ folder, passing this app's folder first.
# This app's name and bundle ID are in app.conf.
#
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PKG="$(swift package --package-path "$HERE" show-dependencies --format json \
    | sed -n 's|.*"path" *: *"\(.*/GraphiteEmber\)".*|\1|p' | head -1)"
if [ -z "$PKG" ]; then
    echo "error: couldn't find the GraphiteEmber package (try: swift package resolve)" >&2
    exit 1
fi
exec "$PKG/Scripts/$(basename "$0")" "$HERE" "$@"
