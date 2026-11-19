#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Furcenzo
#
# Regenerates the README screenshots in Assets/screenshots/. The app draws its bar itself with sample apps
# (STOWAWAY_SNAPSHOT), so nothing of this Mac's menu bar, apps or desktop ends up in the pictures and the
# real menu bar is not touched.
set -euo pipefail
cd "$(dirname "$0")/.."

./scripts/build-app.sh >/dev/null
OUT="Assets/screenshots"
env STOWAWAY_SNAPSHOT="$PWD/$OUT" "build/Stowaway Dev.app/Contents/MacOS/Stowaway" -AppleLanguages "(en)" >/dev/null 2>&1
ls "$OUT"/bar-*.png
