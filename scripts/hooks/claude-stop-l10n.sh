#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Furcenzo
# Part of mac-app-kit (shared scripts of the Furcenzo Mac apps): change it there and run its sync.sh, not here.
#
# Claude Code "Stop" hook (.claude/settings.json): before Claude finishes a turn in which
# app texts changed, check that both languages are complete. Exit code 2 sends the errors
# back to Claude so it fixes them instead of stopping.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"

input="$(cat)"
# Don't loop forever: if Claude is already continuing because of this hook, only warn.
if print -r -- "$input" | grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
    blocking=0
else
    blocking=1
fi

# Only when Swift sources or translations have uncommitted changes.
git status --porcelain -- 'Sources/*.swift' 'Sources/*.strings' 2>/dev/null | grep -q . || exit 0

if ! report="$(./scripts/check-localization.sh 2>&1)"; then
    print -r -- "$report" | grep -E '^(error|check-localization)' >&2
    echo "Every user-facing text must be English in code and translated in every <lang>.lproj/Localizable.strings (see CLAUDE.md)." >&2
    (( blocking )) && exit 2
fi
exit 0
