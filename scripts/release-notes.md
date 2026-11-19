## What's new

@CHANGES@

## Download

**[@ZIP@](@ZIP_URL@)** – for Macs with Apple silicon, macOS 27 or later, English and Slovak.

1. Unzip it and move **Stowaway.app** to /Applications (it must run from there, otherwise macOS hides its own icon too).
2. The app is not notarized by Apple, so macOS may refuse to open it. If it does, open
   **System Settings → Privacy & Security** and click **Open Anyway** next to “Stowaway”, or run:
   `xattr -dr com.apple.quarantine "/Applications/Stowaway.app"`

Or install it with Homebrew: `brew install --cask furcenzo/tap/stowaway`

SHA-256: `@SHA@`
