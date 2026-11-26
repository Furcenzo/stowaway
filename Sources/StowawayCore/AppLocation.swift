// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import Foundation

/// Where an app has to be for macOS to keep its icon. While icons are hidden, macOS 27 lets through the allowed
/// bundle IDs only for apps in /Applications: the same app in ~/Applications or a build folder stays hidden even
/// when its bundle ID is allowed (tried on macOS 27.2).
public enum AppLocation {
    /// Whether macOS honours the allow-list for an app bundle at `path` (nil = unknown, assumed fine).
    public static func canKeepIcon(bundlePath path: String?) -> Bool {
        guard let path else { return true }
        let standardized = (path as NSString).standardizingPath
        // System apps and agents live in /System; macOS shows their icons as before.
        return ["/Applications/", "/System/"].contains { standardized.hasPrefix($0) }
    }
}
