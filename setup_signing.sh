#!/usr/bin/env bash
#
# One-time setup: create a STABLE self-signed code-signing identity in a
# dedicated keychain. Signing the app with a stable identity means rebuilds keep
# their code identity, so macOS keeps the Accessibility grant — no more
# re-granting after every build.
#
# The keychain password below only guards a throwaway, self-signed, local-only
# code-signing certificate (no secrets), so it's fine to keep in the clear.
#
set -euo pipefail

IDENTITY="One Tap Local Signing"
KC="$HOME/Library/Keychains/onetap-signing.keychain-db"
KC_PW="onetap-local"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if security find-identity -p codesigning "$KC" 2>/dev/null | grep -q "$IDENTITY"; then
    echo "Signing identity '$IDENTITY' already present."
    exit 0
fi

[ -f "$KC" ] || security create-keychain -p "$KC_PW" "$KC"
security set-keychain-settings "$KC"           # no auto-lock
security unlock-keychain -p "$KC_PW" "$KC"

cat > "$WORK/openssl.cnf" <<'EOF'
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = One Tap Local Signing
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

# Use the system LibreSSL: it produces a PKCS#12 that macOS `security import`
# can read (Homebrew OpenSSL 3 defaults to a MAC algorithm macOS rejects).
OPENSSL=/usr/bin/openssl

"$OPENSSL" req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" -config "$WORK/openssl.cnf"

"$OPENSSL" pkcs12 -export -out "$WORK/id.p12" -inkey "$WORK/key.pem" -in "$WORK/cert.pem" \
    -name "$IDENTITY" -passout pass:onetap

security import "$WORK/id.p12" -k "$KC" -P onetap -T /usr/bin/codesign -A
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KC_PW" "$KC" >/dev/null 2>&1 || true

# Keep our keychain in the search list alongside the existing ones.
EXISTING=$(security list-keychains -d user | tr -d '"' | xargs)
security list-keychains -d user -s "$KC" $EXISTING

echo "Created signing identity '$IDENTITY'."
security find-identity -p codesigning "$KC" | grep "$IDENTITY" || true
