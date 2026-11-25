# Changelog

User-facing changes in each release. `scripts/release.sh <version> --publish` copies the section of that
version into the GitHub Release notes, so add a section before publishing.

## Unreleased

- The bar under the Stowaway icon wraps into rows instead of running off the screen edge.
- No more false "Move Stowaway to the Applications folder" warning when the menu bar is redrawn, e.g. after
  the display wakes up.

## 0.1.1

- New app icon: icons dropping from the menu bar into a suitcase.

## 0.1.0

- First version for macOS 27: hides the menu bar icons of all apps except the ones you keep, and opens them
  from a bar under the Stowaway icon.
- Reorder the bar's icons by drag and drop; hover for the app's name.
- Shows every icon again and explains why when macOS doesn't let it hide them.
