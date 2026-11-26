# Changelog

User-facing changes in each release. `scripts/release.sh <version> --publish` copies the section of that
version into the GitHub Release notes, so add a section before publishing.

## Unreleased

## 0.1.4

- No more "macOS refused to hide the icons" after unlocking the Mac: Stowaway itself cancelled its request when
  several apps started at once. After waking up or unlocking it now checks that hiding works and fixes it by itself, and when
  macOS refuses, it tries again a few times before showing every icon.
- New background processes without any UI no longer make the menu bar redraw.
- Hidden icons no longer flash for a split second when Stowaway changes what is hidden (e.g. when opening an icon
  from the bar).

## 0.1.3

- Icons of menu bar apps started while Stowaway runs show up in the bar (macOS doesn't announce the launch of
  apps without a Dock icon, so Stowaway never learned them).

## 0.1.2

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
