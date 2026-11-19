#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Furcenzo
# Part of mac-app-kit (shared scripts of the Furcenzo Mac apps): change it there and run its sync.sh, not here.
#
# Renders the app icon and builds the .icns copied into the app by scripts/build-app.sh.
# The drawing is app-specific: ICON_SOURCE (default scripts/icon/AppIcon.swift) is run as
# `swift <ICON_SOURCE> <output.png>` and writes a 1024 × 1024 PNG. Results (paths from app.conf):
#   ICON_PNG   (default Assets/AppIcon.png, for the README and the website)
#   ICON_ICNS  (default Assets/AppIcon.icns)
# Run it after changing the drawing and commit both files.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/app-config.sh

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
swift "$ICON_SOURCE" "$WORK/icon.png"

SET="$WORK/AppIcon.iconset"
mkdir -p "$SET" "$(dirname "$ICON_ICNS")" "$(dirname "$ICON_PNG")"
for size in 16 32 128 256 512; do
    sips -z $size $size "$WORK/icon.png" --out "$SET/icon_${size}x${size}.png" >/dev/null
    sips -z $((size * 2)) $((size * 2)) "$WORK/icon.png" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil --convert icns --output "$ICON_ICNS" "$SET"
cp "$WORK/icon.png" "$ICON_PNG"
echo "Done: $ICON_PNG, $ICON_ICNS"
