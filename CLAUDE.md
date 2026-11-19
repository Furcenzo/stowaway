# MenuBarLab – notes for Claude Code

Native macOS app (Swift 6, SwiftUI, Swift Package Manager, macOS 15+).
`Sources/MenuBarLabCore` = pure logic, no UI (tested in `Tests/MenuBarLabCoreTests`); `Sources/MenuBarLab` = the app.

Build: `swift build`, tests: `swift test`, app bundle: `./scripts/build-app.sh` → `build/MenuBarLab Dev.app`,
build + restart: `./scripts/run.sh [sk|en]`.

## Shared scripts (mac-app-kit)

`scripts/` (except `scripts/icon/` and `scripts/release-notes.md`), `.githooks/` and `.claude/settings.json`
are copies from mac-app-kit (`../mac-app-kit`, shared with the author's other Mac apps). Don't edit them here:
change them in the kit and run its `./sync.sh` (`./sync.sh --check` lists differences). The settings of this
app (name, bundle ID, repository, cask…) are in `app.conf`.

**Development builds are "MenuBarLab Dev"** (`build/MenuBarLab Dev.app`, bundle ID `io.github.furcenzo.menubarlab.dev`, the
default of `build-app.sh`); only `release.sh` and `install-local.sh` build the real `MenuBarLab.app` with
`io.github.furcenzo.menubarlab` and they delete their staging copies afterwards. Reason: the login item, Spotlight and
LaunchServices pick an app by bundle ID and file name.

App icon: `Assets/AppIcon.icns` + `AppIcon.png`, drawn by `scripts/icon/AppIcon.swift` – regenerate both with
`./scripts/make-icon.sh` and commit them.

## Code signing and permissions

macOS ties privacy permissions to the code signature, so development builds are signed with the local
self-signed certificate **"MenuBarLab Local Dev"** (`scripts/build-app.sh` uses it automatically when it
exists, otherwise signs ad-hoc with a warning). The certificate is created once by the user with
`./scripts/setup-dev-signing.sh` – it needs the login password, so never run it for the user without asking;
give them the command instead.

## Localization – the app is bilingual (English + Slovak)

Every change that adds or changes a user-facing text must keep **both languages** complete.

- **Code contains English only.** The English text is the localization key. Never write Slovak
  (or any other language) into string literals in `Sources/` – the check fails on Slovak diacritics.
- **Slovak goes to** `Sources/MenuBarLab/Resources/sk.lproj/Localizable.strings` (key = the English text,
  exactly as in code, including punctuation and `…`). Keep the file sorted alphabetically (case-insensitive).
  `en.lproj` stays empty on purpose.
- Interpolated values become format specifiers in the key: `Text("Delete \(name)?")` →
  `"Delete %@?"`; `Int` → `%lld`, `Int32` → `%d`, `String` → `%@`. The translation must use the same
  specifiers (use `%1$@`, `%2$@` if the order has to change).
- **Which APIs translate automatically:** SwiftUI initializers that take a *string literal*
  (`Text("…")`, `Button("…")`, `Label`, `Toggle`, `Section`, `.help("…")`…) use `LocalizedStringKey`.
  A `String` **variable** passed to them is shown verbatim (not translated).
  - For texts built in code (menus, `NSAlert`, window titles) use `String(localized: "…")`.
  - Text that must not be translated (names, paths): pass a `String` variable or use `Text(verbatim:)`.
- Avoid grammar that depends on the number (Slovak has 3 plural forms): prefer `"Items: %lld"`.
- **Always run** `./scripts/check-localization.sh` after changing texts. It lists every localizable string
  via the compiler and fails on missing translations, mismatched format specifiers, or Slovak in code;
  it warns about unused translations (delete them).
- Enforced by hooks: the Claude Code `Stop` hook (`.claude/settings.json` →
  `scripts/hooks/claude-stop-l10n.sh`) and the git pre-commit hook (`.githooks/pre-commit`,
  enable with `git config core.hooksPath .githooks`).
- To check the UI in a given language: `./scripts/run.sh sk` (or `en`).

## Releases

`./scripts/release.sh <version>` builds a universal (Apple silicon + Intel), ad-hoc signed app into
`build/release/` and zips it into `build/`. `./scripts/release.sh <version> --publish` also tags `v<version>`,
pushes the tag and creates a GitHub Release with the zip; its "What's new" is the `## <version>` section of
`CHANGELOG.md` (the script refuses to publish without it), the rest comes from `scripts/release-notes.md`, and
it bumps `version`/`sha256` of the cask `CASK` (`app.conf`) in the `Furcenzo/homebrew-tap` repository. When you
make a user-facing change, add a line under `## Unreleased` in `CHANGELOG.md`; at release time rename that
heading to the version. Publishing is public and irreversible – only run `--publish` when the user explicitly
asked for it.

## Conventions

- Every source file starts with `// SPDX-License-Identifier: GPL-3.0-or-later` and
  `// Copyright (C) 2026 Furcenzo` (in `Package.swift` after the `swift-tools-version` line; `#` comments
  in shell scripts).
- README, CLAUDE.md, commit messages and code comments are in English.
- Commits are authored by `Furcenzo <60021487+Furcenzo@users.noreply.github.com>` (set in this repository's
  git config).
- Bundle ID is `io.github.furcenzo.menubarlab`.
