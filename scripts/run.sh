#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Furcenzo
# Part of mac-app-kit (shared scripts of the Furcenzo Mac apps): change it there and run its sync.sh, not here.
#
# Development loop: build the development app in build/ ("<APP_NAME> Dev.app"), quit the running one and start the
# new build (from DEV_INSTALL_DIR, e.g. /Applications, when app.conf sets it: the build is copied there first).
#   ./scripts/run.sh          English UI (or the macOS language)
#   ./scripts/run.sh sk       force a language
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/app-config.sh

./scripts/build-app.sh
if [[ "$RUN_QUITS_INSTALLED" == "1" ]]; then
    # Every running copy: the dev build and, with the same executable name, the installed app too.
    pkill -x "$EXECUTABLE" 2>/dev/null && sleep 0.5 || true
else
    # Only builds from build/ – the installed app keeps running next to it. build/<APP_NAME>.app is where
    # development builds used to be (build-app.sh has removed it, but a copy started from there may still run).
    COPIES=("$PWD/build/$DEV_APP_BUNDLE" "$PWD/build/$APP_BUNDLE")
    [[ -n "$DEV_INSTALL_DIR" ]] && COPIES+=("$DEV_APP_PATH")
    for copy in "${COPIES[@]}"; do
        BUILT="$(print -r -- "$copy/Contents/MacOS/$EXECUTABLE" | sed 's/[][\\.*^$(){}?+|]/\\&/g')"
        pkill -f "^$BUILT" 2>/dev/null && sleep 0.5 || true
    done
fi
if [[ -n "$DEV_INSTALL_DIR" ]]; then
    rm -rf "$DEV_APP_PATH"
    ditto "build/$DEV_APP_BUNDLE" "$DEV_APP_PATH"
fi
if [[ -n "${1:-}" ]]; then
    open -n "$DEV_APP_PATH" --args -AppleLanguages "($1)"
else
    open -n "$DEV_APP_PATH"
fi
NAME="$APP_NAME"
[[ "$DEV_CHANNEL" == "1" ]] && NAME="$APP_NAME Dev"
if [[ "$AGENT_APP" == "1" ]]; then
    echo "$NAME is running – look for its icon in the menu bar."
else
    echo "$NAME is running."
fi
if [[ "$RUN_QUITS_INSTALLED" == "1" && -d "/Applications/$APP_BUNDLE" ]]; then
    echo "(The installed $APP_NAME was quit. Back to it: open \"/Applications/$APP_BUNDLE\")"
fi
