#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Furcenzo
# Part of mac-app-kit (shared scripts of the Furcenzo Mac apps): change it there and run its sync.sh, not here.
#
# Checks that every user-facing text in the code has a translation in every
# <RESOURCES>/<lang>.lproj/Localizable.strings (app.conf; default Sources/<EXECUTABLE>/Resources) (except en, the development language).
#
# 1. The Swift compiler lists every localizable string (LocalizedStringKey literals,
#    String(localized:)) while building into .build/l10n.
# 2. Errors: a key without a translation, a translation whose format specifiers (%@, %lld, %d…)
#    don't match the key, or a string literal in Sources with Slovak diacritics
#    (texts in code must be English; the Slovak version belongs in sk.lproj).
# 3. Warnings: translations whose key is no longer used in the code.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/app-config.sh

OUT="$PWD/.build/l10n/strings"
build() {
    mkdir -p .build/l10n
    swift build --build-path .build/l10n \
        -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$OUT" >.build/l10n/build.log 2>&1 || {
        tail -30 .build/l10n/build.log
        echo "check-localization: the build failed (see .build/l10n/build.log)" >&2
        exit 1
    }
}
# The compiler only writes the list for files it recompiles, so the lists from earlier runs are kept.
# If there are none yet (first run), build from scratch.
build
if [[ -z "$(ls "$OUT"/*.stringsdata 2>/dev/null)" ]]; then
    rm -rf .build/l10n
    build
fi

/usr/bin/python3 -I - "$OUT" "$RESOURCES" Sources <<'PY'
import glob, json, pathlib, re, subprocess, sys

strings_dir, resources, sources = sys.argv[1:4]

used = {}
for f in glob.glob(f"{strings_dir}/*.stringsdata"):
    data = json.load(open(f))
    if not pathlib.Path(data["source"]).exists():
        continue  # list left over from a deleted source file
    for items in data["tables"].values():
        for item in items:
            if item["key"]:
                used.setdefault(item["key"], f'{pathlib.Path(data["source"]).name}:{item["location"]["startingLine"]}')

spec = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|z|t|j)?[@dDiuUxXoOfeEgGcCsSp]")
def specs(s):
    return sorted(re.sub(r"^%(?:\d+\$)?", "%", m) for m in spec.findall(s.replace("%%", "")))

errors, warnings = [], []
for path in sorted(glob.glob(f"{resources}/*.lproj/Localizable.strings")):
    lang = pathlib.Path(path).parent.stem
    if lang == "en":
        continue
    table = json.loads(subprocess.run(["plutil", "-convert", "json", "-o", "-", path],
                                      check=True, capture_output=True).stdout)
    for key, where in sorted(used.items()):
        if key not in table:
            errors.append(f'{lang}: missing translation for "{key}" ({where})')
        elif specs(key) != specs(table[key]):
            errors.append(f'{lang}: format specifiers differ for "{key}": {specs(key)} vs {specs(table[key])}')
    for key in sorted(set(table) - set(used)):
        warnings.append(f'{lang}: unused translation "{key}"')

slovak = re.compile(r'"(?:[^"\\\n]|\\.)*[áäčďéíĺľňóôŕšťúýžÁÄČĎÉÍĹĽŇÓÔŔŠŤÚÝŽ](?:[^"\\\n]|\\.)*"')
for path in sorted(glob.glob(f"{sources}/**/*.swift", recursive=True)):
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        code = line.split("//")[0] if not line.lstrip().startswith("//") else ""
        if slovak.search(code):
            errors.append(f"{path}:{n}: Slovak text in code – write it in English and translate it in sk.lproj")

for w in warnings:
    print("warning:", w)
for e in errors:
    print("error:", e, file=sys.stderr)
print(f"check-localization: {len(used)} texts, {len(errors)} errors, {len(warnings)} warnings")
sys.exit(1 if errors else 0)
PY
