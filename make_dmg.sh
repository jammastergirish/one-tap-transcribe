#!/usr/bin/env bash
# Thin wrapper: the shared script lives in the GraphiteEmber package, which
# must be checked out at ../../GraphiteEmber. App settings are in app.conf.
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/../../GraphiteEmber/Scripts/make_dmg.sh" "$HERE" "$@"
