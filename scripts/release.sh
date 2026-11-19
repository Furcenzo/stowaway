#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Furcenzo
# Part of mac-app-kit (shared scripts of the Furcenzo Mac apps): change it there and run its sync.sh, not here.
#
# Builds a downloadable release of the app (names, repository and cask come from app.conf).
#   ./scripts/release.sh 0.2.0            build + zip into build/ (nothing is published)
#   ./scripts/release.sh 0.2.0 --publish  also tag v0.2.0, push the tag and create a GitHub Release
#                                         (its "What's new" comes from the "## 0.2.0" section of CHANGELOG.md,
#                                         the rest from scripts/release-notes.md), update the cask in the
#                                         Homebrew tap repository and refresh dev.furian.sk
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/app-config.sh

VERSION="${1:-}"
PUBLISH="${2:-}"
if [[ ! "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    echo "usage: $0 <major.minor.patch> [--publish]" >&2
    exit 1
fi
TAG="v$VERSION"
ZIP="build/$ZIP_NAME-$VERSION.zip"

if [[ "$PUBLISH" == "--publish" ]]; then
    [[ -z "$(git status --porcelain)" ]] || { echo "The working tree has uncommitted changes." >&2; exit 1; }
    [[ "$(git branch --show-current)" == "main" ]] || { echo "Releases are made from main." >&2; exit 1; }
    git fetch --quiet origin main --tags
    [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || { echo "main is not in sync with origin/main – push or pull first." >&2; exit 1; }
    ! git rev-parse -q --verify "refs/tags/$TAG" >/dev/null || { echo "Tag $TAG already exists." >&2; exit 1; }
    # The "## <version>" section of CHANGELOG.md, without its heading.
    CHANGES="$(awk -v v="## $VERSION" '$0 == v { found = 1; next } found && /^## / { exit } found' CHANGELOG.md \
        | sed -e '/./,$!d' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')"
    [[ -n "$CHANGES" ]] || { echo "CHANGELOG.md has no \"## $VERSION\" section with the changes – add it first." >&2; exit 1; }
    [[ -f "$RELEASE_NOTES" ]] || { echo "$RELEASE_NOTES (the download instructions) is missing." >&2; exit 1; }
fi

swift test
./scripts/check-localization.sh
# Public builds are ad-hoc signed: the local "<APP_NAME> Local Dev" certificate is only for this Mac.
VERSION="$VERSION" UNIVERSAL=1 CHANNEL=release SIGN_IDENTITY=- OUTPUT_DIR=build/release ./scripts/build-app.sh

rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "build/release/$APP_BUNDLE" "$ZIP"
SHA="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
# Only the zip is needed. A second app with the real bundle ID left on disk could stand in for the
# installed one (login item, Spotlight).
"$LSREGISTER" -u "build/release/$APP_BUNDLE" 2>/dev/null || true
rm -rf build/release
echo "Release archive: $PWD/$ZIP"
echo "SHA-256: $SHA"

[[ "$PUBLISH" == "--publish" ]] || exit 0

NOTES="$(mktemp)"
TAP_DIR="$(mktemp -d)"
trap 'rm -rf "$NOTES" "$TAP_DIR"' EXIT
# scripts/release-notes.md with its placeholders filled in.
ZIP_FILE="${ZIP:t}"
TEXT="$(<"$RELEASE_NOTES")"
TEXT="${TEXT//@CHANGES@/$CHANGES}"
TEXT="${TEXT//@ZIP_URL@/https://github.com/$GITHUB_REPO/releases/download/$TAG/$ZIP_FILE}"
TEXT="${TEXT//@ZIP@/$ZIP_FILE}"
TEXT="${TEXT//@VERSION@/$VERSION}"
TEXT="${TEXT//@SHA@/$SHA}"
print -r -- "$TEXT" > "$NOTES"

git tag -a "$TAG" -m "$APP_NAME $VERSION"
git push origin "$TAG"
gh release create "$TAG" "$ZIP" --title "$APP_NAME $VERSION" --notes-file "$NOTES" --generate-notes

if [[ -n "$CASK" ]]; then
    # Point the Homebrew cask (brew install --cask <tap>/<CASK>) at the new release.
    git clone --quiet "https://github.com/$TAP_REPO.git" "$TAP_DIR"
    CASK_FILE="$TAP_DIR/Casks/$CASK.rb"
    perl -pi -e "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/" "$CASK_FILE"
    grep -q "version \"$VERSION\"" "$CASK_FILE" && grep -q "sha256 \"$SHA\"" "$CASK_FILE" || { echo "Updating $CASK_FILE failed." >&2; exit 1; }
    git -C "$TAP_DIR" commit --quiet --all --message "$CASK $VERSION"
    git -C "$TAP_DIR" push --quiet origin HEAD
    echo "Updated $TAP_REPO: $CASK $VERSION"
fi

# Refresh the showroom website https://dev.furian.sk (app icon and screenshots; its version numbers and download
# links follow the latest release by themselves). Runs only where that site's repository is checked out (the
# author's Mac; SHOWROOM_SITE_DIR overrides the path). A failure here does not undo the release.
SITE_UPDATE="${SHOWROOM_SITE_DIR:-$HOME/Projects/Private/dev.furian.sk}/scripts/update-site.sh"
if [[ -n "$SITE_SLUG" && -x "$SITE_UPDATE" ]]; then
    "$SITE_UPDATE" "$SITE_SLUG" || echo "Updating dev.furian.sk failed – run $SITE_UPDATE $SITE_SLUG later." >&2
fi
