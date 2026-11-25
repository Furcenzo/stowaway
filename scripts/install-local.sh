#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Furcenzo
# Part of mac-app-kit (shared scripts of the Furcenzo Mac apps): change it there and run its sync.sh, not here.
#
# For the author's own Mac: builds the latest tag and installs it into /Applications, signed like the public
# releases ("Furcenzo Release"), so it shares their permissions; "<APP_NAME> Local Dev" when that is missing.
#   ./scripts/install-local.sh          version = the latest git tag (e.g. v0.1.1 → 0.1.1)
#   ./scripts/install-local.sh 0.2.0
#
# When Homebrew manages the app (cask adopted with `brew install --cask --adopt`): after a release run
# `brew upgrade --cask <cask>`, then this script – Homebrew only checks the version number, so it keeps
# treating the replaced app as its own.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/app-config.sh

VERSION="${1:-$(git describe --tags --abbrev=0 | sed 's/^v//')}"
if [[ ! "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    echo "usage: $0 [major.minor.patch]" >&2
    exit 1
fi
IDENTITY="$(release_identity)" || IDENTITY="$(dev_identity)" \
    || { echo "No signing certificate – run scripts/setup-dev-signing.sh --release first." >&2; exit 1; }

VERSION="$VERSION" CHANNEL=release OUTPUT_DIR=build/install SIGN_IDENTITY="$IDENTITY" ./scripts/build-app.sh
# Quit the running app (SIGTERM, so it can clean up); the new one starts below.
pkill -x "$EXECUTABLE" 2>/dev/null && sleep 1 || true
rm -rf "/Applications/$APP_BUNDLE"
ditto "build/install/$APP_BUNDLE" "/Applications/$APP_BUNDLE"
# Keep /Applications the only app with the real bundle ID (the login item follows the bundle ID).
"$LSREGISTER" -u "build/install/$APP_BUNDLE" 2>/dev/null || true
rm -rf build/install
open "/Applications/$APP_BUNDLE"
echo "Installed $APP_NAME $VERSION (signed with $IDENTITY) into /Applications and started it."
