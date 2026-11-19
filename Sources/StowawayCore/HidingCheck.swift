// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import Foundation

/// Why hiding was turned off. Hiding relies on a private macOS API, so Stowaway checks that it really works
/// and shows every icon again when it doesn't.
public enum HidingProblem: Equatable, Sendable {
    /// The private API is missing in this macOS version.
    case unavailable
    /// macOS refused the request.
    case refused
    /// macOS hid Stowaway's own icon too (it doesn't run from /Applications), so it couldn't be used any more.
    case ownIconHidden
    /// macOS accepted the request but the icons stayed visible.
    case notHidden
}

public enum HidingCheck {
    /// Checks the menu bar a moment after hiding was turned on.
    /// - Parameters:
    ///   - visible: bundle ID → icons the menu bar shows now.
    ///   - own: Stowaway's bundle ID.
    ///   - expectedHidden: running apps with icons that should be hidden now.
    public static func problem(visible: [String: Int], own: String, expectedHidden: [String]) -> HidingProblem? {
        if visible[own, default: 0] == 0 { return .ownIconHidden }
        // Only when none of them got hidden: a single app macOS keeps visible is not a reason to give up.
        if !expectedHidden.isEmpty, expectedHidden.allSatisfy({ visible[$0, default: 0] > 0 }) { return .notHidden }
        return nil
    }
}
