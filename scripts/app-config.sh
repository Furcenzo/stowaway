# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Furcenzo
# Part of mac-app-kit (shared scripts of the Furcenzo Mac apps): change it there and run its sync.sh, not here.
#
# Sourced by the other scripts after `cd` to the repository root: reads app.conf (the settings of this app)
# and fills in the defaults of everything app.conf leaves out.

[[ -f app.conf ]] || { echo "app.conf is missing in $PWD" >&2; exit 1; }
source ./app.conf

: "${APP_NAME:?app.conf: APP_NAME is missing}"
: "${EXECUTABLE:?app.conf: EXECUTABLE is missing}"
: "${BUNDLE_ID:?app.conf: BUNDLE_ID is missing}"
: "${GITHUB_REPO:?app.conf: GITHUB_REPO is missing}"

RESOURCES="${RESOURCES:-Sources/$EXECUTABLE/Resources}"   # *.lproj folders (and the icon, if it is there)
ICON_ICNS="${ICON_ICNS:-Assets/AppIcon.icns}"              # copied into the app
ICON_PNG="${ICON_PNG:-Assets/AppIcon.png}"                 # 1024 × 1024, for the README and the website
ICON_SOURCE="${ICON_SOURCE:-scripts/icon/AppIcon.swift}"   # draws ICON_PNG, see scripts/make-icon.sh
ZIP_NAME="${ZIP_NAME:-${APP_NAME// /-}}"                   # build/<ZIP_NAME>-<version>.zip
MIN_MACOS="${MIN_MACOS:-15.0}"
CATEGORY="${CATEGORY:-public.app-category.utilities}"
AGENT_APP="${AGENT_APP:-0}"                                # 1 = menu bar only, no Dock icon (LSUIElement)
DEV_CHANNEL="${DEV_CHANNEL:-1}"                            # 1 = development builds are "<APP_NAME> Dev"
RUN_QUITS_INSTALLED="${RUN_QUITS_INSTALLED:-0}"            # 1 = run.sh also quits the installed app
DEV_INSTALL_DIR="${DEV_INSTALL_DIR:-}"                     # e.g. /Applications: run.sh starts the dev build from there
DEV_IDENTITY="${DEV_IDENTITY:-$APP_NAME Local Dev}"        # local signing certificate, see setup-dev-signing.sh
RELEASE_IDENTITY="${RELEASE_IDENTITY:-Furcenzo Release}"   # signs public releases (all apps); "-" = ad-hoc
COPYRIGHT="${COPYRIGHT:-Copyright (C) 2026 Furcenzo. GPL-3.0-or-later.}"
INFO_PLIST_EXTRA="${INFO_PLIST_EXTRA:-}"                   # extra <key>…</key><…> lines for Info.plist
RELEASE_NOTES="${RELEASE_NOTES:-scripts/release-notes.md}"
CASK="${CASK:-}"                                           # Casks/<CASK>.rb in TAP_REPO; empty = no cask
TAP_REPO="${TAP_REPO:-Furcenzo/homebrew-tap}"
SITE_SLUG="${SITE_SLUG:-}"                                 # app name for dev.furian.sk's update-site.sh

APP_BUNDLE="$APP_NAME.app"                                 # the real app: releases, /Applications
# Development builds (build/, DEV_CHANNEL=1) get their own file name too, so Spotlight, Finder and LaunchServices
# never take them for the installed app.
DEV_APP_BUNDLE="$APP_BUNDLE"
[[ "$DEV_CHANNEL" == "1" ]] && DEV_APP_BUNDLE="$APP_NAME Dev.app"
# Where the development app is started from: build/, or DEV_INSTALL_DIR when set (macOS treats some apps differently
# outside /Applications, e.g. menu bar icons). Other tools can read this too.
DEV_APP_PATH="build/$DEV_APP_BUNDLE"
if [[ -n "$DEV_INSTALL_DIR" ]]; then
    [[ "$DEV_CHANNEL" == "1" ]] || { echo "app.conf: DEV_INSTALL_DIR needs DEV_CHANNEL=1 (it would replace the installed app)" >&2; exit 1; }
    DEV_APP_PATH="$DEV_INSTALL_DIR/$DEV_APP_BUNDLE"
fi
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

# Prints the name of the "<APP_NAME> Local Dev" certificate when it is in the keychain.
dev_identity() {
    security find-identity -p codesigning | grep -q "\"$DEV_IDENTITY\"" && print -r -- "$DEV_IDENTITY"
}

# Prints the name of the release certificate ("Furcenzo Release") when it is in the keychain.
release_identity() {
    security find-identity -p codesigning | grep -q "\"$RELEASE_IDENTITY\"" && print -r -- "$RELEASE_IDENTITY"
}
