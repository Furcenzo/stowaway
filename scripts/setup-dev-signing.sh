#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Furcenzo
# Part of mac-app-kit (shared scripts of the Furcenzo Mac apps): change it there and run its sync.sh, not here.
#
# One-time setup for development: creates a self-signed code signing certificate
# "<APP_NAME> Local Dev" in your login keychain. scripts/build-app.sh then signs every build with it,
# so macOS keeps the app's permissions (Accessibility, Screen Recording, files…) between builds.
#
# Run it yourself in Terminal – macOS asks for your login password to trust the certificate:
#   ./scripts/setup-dev-signing.sh
#
# The certificate is only good for signing apps on this Mac; it is not an Apple Developer ID and
# cannot be used for public releases. Remove it any time in Keychain Access (login → My Certificates
# → "<APP_NAME> Local Dev" → Delete). Based on AltTab's scripts/codesign (lwouis/alt-tab-macos, GPL-3.0).
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/app-config.sh

NAME="$DEV_IDENTITY"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -q "\"$NAME\""; then
    echo "The \"$NAME\" certificate is already set up – nothing to do."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if security find-certificate -c "$NAME" "$KEYCHAIN" >/dev/null 2>&1; then
    echo "The certificate exists but is not trusted yet – only the trust step is left."
    security find-certificate -c "$NAME" -p "$KEYCHAIN" > "$TMP/cert.crt"
else
    # A code signing certificate: extended key usage "Code Signing" plus Apple's marker extension
    # 1.2.840.113635.100.6.1.14 (see https://apple.stackexchange.com/q/359997).
    cat > "$TMP/cert.conf" <<EOF
[ req ]
distinguished_name = req_name
prompt = no
[ req_name ]
CN = $NAME
[ extensions ]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,1.3.6.1.5.5.7.3.3
1.2.840.113635.100.6.1.14 = critical,DER:0500
EOF
    # macOS's own LibreSSL writes a PKCS#12 file that `security import` understands
    # (Homebrew's OpenSSL 3+ would need -legacy).
    /usr/bin/openssl req -x509 -new -newkey rsa:2048 -nodes -days 3650 -sha256 \
        -config "$TMP/cert.conf" -extensions extensions \
        -keyout "$TMP/cert.key" -out "$TMP/cert.crt" 2>/dev/null
    PASSWORD="$(/usr/bin/openssl rand -hex 16)"
    /usr/bin/openssl pkcs12 -export -name "$NAME" -inkey "$TMP/cert.key" -in "$TMP/cert.crt" \
        -out "$TMP/cert.p12" -passout "pass:$PASSWORD"
    # -T: codesign may use the private key without asking every time.
    security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$PASSWORD" -T /usr/bin/codesign
    echo "Certificate \"$NAME\" added to the login keychain."
fi

echo
echo "Now macOS asks for your login password to trust the certificate for code signing…"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.crt"

echo
if security find-identity -v -p codesigning | grep "\"$NAME\""; then
    echo "Done. Build the app with ./scripts/build-app.sh – it is signed with \"$NAME\" from now on."
    echo "The first build may ask \"codesign wants to sign using key …\": enter your password and click Always Allow."
else
    echo "The certificate is in the keychain but macOS does not list it as valid for code signing." >&2
    echo "Open Keychain Access → login → My Certificates → \"$NAME\" → Trust → Code Signing: Always Trust." >&2
    exit 1
fi
