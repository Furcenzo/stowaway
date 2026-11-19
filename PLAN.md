# Stowaway – plan

A menu bar manager for macOS 27: keep only the icons you want in the menu bar, open the others from a bar under the
Stowaway icon. Built because the window-based technique of Ice and Thaw 2 no longer works on macOS 27.

## How macOS 27 changed the menu bar (verified on 27.2.1)

- Status items are no longer separate windows. MenuBarAgent draws every icon into one menu bar window, so moving or
  measuring icon windows (Ice, Thaw 2, Bartender 5) and the "wide separator pushes icons off screen" trick are gone:
  an oversized status item is simply dropped.
- MenuBarAgent's Accessibility tree has one group per visible icon, with the owning app, frame and `AXPress`
  (`AXPress` is unsupported for third-party icons). Hidden icons are not in it, and many apps drop their own
  `AXExtrasMenuBar` while hidden.
- macOS has its own overflow arrow next to the notch (`menu-bar-overflow-indicator`).
- Positions are stored by MenuBarAgent in a protected container; ⌘-dragging still works and is remembered.

## MVP

1. **Hiding per app** – private `MBAssessmentModeAssertion` (MenuBarClientCore) with an allow-list of bundle IDs
   and system items (`MBSystemItemIdentifier`: battery, Bluetooth, clock, displays, keyboard, sound, Wi-Fi,
   screen mirroring, Control Center). Quitting or crashing restores all icons. *Done.*
2. **Bar** – left click on the Stowaway icon shows the hidden apps (app icons, no Screen Recording needed).
   A click allows the app for a moment, clicks its real icon (CGEvent, needs Accessibility) and hides it again
   when its menu closes. *Done; no flicker (checked by the user).*
3. **List** – which apps have icons: learned from MenuBarAgent while visible (at launch, when opened, and by
   briefly showing newly launched apps). *Done.*
4. **Settings** – right-click menu: keep apps/system items in the menu bar, show all, quit. *Done.*
5. **Order** – the icons left in the menu bar are ordered with macOS's own ⌘-drag (remembered by macOS); the bar's
   icons are reordered by drag and drop (a line shows where the icon lands). *Done.*
6. **Plan B safety net** – see below, step 1. *Done.*

## Limits

- Per app, not per icon: an app with several icons (Stats) is either all visible or all hidden.
- Stowaway must run from /Applications, otherwise macOS hides its own icon too (dev builds are copied to
  `/Applications/Stowaway Dev.app` for testing).
- Only the nine system items above can stay; Focus, Siri, Spotlight and others are hidden whenever hiding is on.
- The bar shows app icons, not the live icon (that would need Screen Recording).

## Risk: private API

Everything depends on `MBAssessmentModeAssertion`, meant for exam (assessment) mode. Apple can change or restrict
it in any macOS update (Thaw 3 depends on it too).

Plan B, in order:
1. Detect it: if the classes are missing, activation fails, the icons stay visible or Stowaway's own icon gets
   hidden, show all icons and tell the user (no silent breakage). *Done* (`HidingCheck`).
2. Fall back to macOS's own overflow: ⌘-drag the unwanted icons to the left of the overflow arrow so macOS hides them
   behind it, and open them from the bar by expanding the overflow (`AXPress` on the arrow) and clicking the icon.
3. Last resort: System Settings → Menu Bar → "Allow in the Menu Bar" per app (no access to the hidden icons).

## Credits

No code from Ice or Thaw is used; their findings (GPL-3.0) informed the research. If code is taken later, credit the
author in the file and in README.
