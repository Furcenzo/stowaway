#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Furcenzo
# Part of mac-app-kit (shared scripts of the Furcenzo Mac apps): change it there and run its sync.sh, not here.
#
# One-time setup of a self-signed code signing certificate in your login keychain:
#   ./scripts/setup-dev-signing.sh            "<APP_NAME> Local Dev": scripts/build-app.sh signs every development
#                                             build with it, so macOS keeps the app's permissions (Accessibility,
#                                             Screen Recording, files…) between builds
#   ./scripts/setup-dev-signing.sh --release  "Furcenzo Release" (RELEASE_IDENTITY), shared by all the apps:
#                                             scripts/release.sh signs public releases with it, so the users keep
#                                             the permissions across updates. Also saves a backup (.p12) to
#                                             ~/.config/furcenzo-signing (outside iCloud-synced folders, only
#                                             readable by you) and its password to the login keychain; copy both
#                                             into a password manager: without this exact certificate the next
#                                             release looks like a new app and every user has to allow it again
#
# Run it yourself in Terminal – macOS asks for your login password to trust the certificate.
#
# Neither is an Apple Developer ID: the apps stay unnotarized (Gatekeeper still asks). Remove a certificate in
# Keychain Access (login → My Certificates → Delete). Based on AltTab's scripts/codesign (lwouis/alt-tab-macos,
# GPL-3.0).
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/app-config.sh

NAME="$DEV_IDENTITY"
DAYS=3650
if [[ "${1:-}" == "--release" ]]; then
    NAME="$RELEASE_IDENTITY"
    DAYS=7300
elif [[ -n "${1:-}" ]]; then
    echo "usage: $0 [--release]" >&2
    exit 1
fi
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
    /usr/bin/openssl req -x509 -new -newkey rsa:2048 -nodes -days $DAYS -sha256 \
        -config "$TMP/cert.conf" -extensions extensions \
        -keyout "$TMP/cert.key" -out "$TMP/cert.crt" 2>/dev/null
    PASSWORD="$(/usr/bin/openssl rand -hex 16)"
    /usr/bin/openssl pkcs12 -export -name "$NAME" -inkey "$TMP/cert.key" -in "$TMP/cert.crt" \
        -out "$TMP/cert.p12" -passout "pass:$PASSWORD"
    # -T: codesign may use the private key without asking every time.
    security import "$TMP/cert.p12" -k "$KEYCHAIN" -P "$PASSWORD" -T /usr/bin/codesign
    echo "Certificate \"$NAME\" added to the login keychain."
    if [[ "$NAME" == "$RELEASE_IDENTITY" ]]; then
        # Not in ~/Documents or ~/Desktop: those may sync to iCloud. The password goes to the keychain, never to
        # the terminal (its output may end up in logs or transcripts).
        BACKUP_DIR="$HOME/.config/furcenzo-signing"
        BACKUP="$BACKUP_DIR/$NAME.p12"
        mkdir -p "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"
        (umask 077 && cp "$TMP/cert.p12" "$BACKUP")
        security add-generic-password -U -a "$USER" -s "$NAME backup" -w "$PASSWORD" "$KEYCHAIN"
        echo
        echo "Backup: $BACKUP"
        echo "Its password is in the login keychain as \"$NAME backup\" (security find-generic-password -s \"$NAME backup\" -w)."
        echo "Copy both into your password manager. To restore on another Mac:"
        echo "  security import \"$NAME.p12\" -k ~/Library/Keychains/login.keychain-db -P <password> -T /usr/bin/codesign"
        echo "and run this script with --release again (it only adds the trust)."
    fi
fi

echo
echo "Now macOS asks for your login password to trust the certificate for code signing…"
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.crt"

echo
if security find-identity -v -p codesigning | grep "\"$NAME\""; then
    if [[ "$NAME" == "$RELEASE_IDENTITY" ]]; then
        echo "Done. scripts/release.sh signs the releases of every app with \"$NAME\" from now on."
    else
        echo "Done. Build the app with ./scripts/build-app.sh – it is signed with \"$NAME\" from now on."
    fi
    echo "The first build may ask \"codesign wants to sign using key …\": enter your password and click Always Allow."
else
    echo "The certificate is in the keychain but macOS does not list it as valid for code signing." >&2
    echo "Open Keychain Access → login → My Certificates → \"$NAME\" → Trust → Code Signing: Always Trust." >&2
    exit 1
fi
