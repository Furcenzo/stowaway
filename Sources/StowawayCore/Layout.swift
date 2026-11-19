// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import Foundation

/// System menu bar items that macOS 27 lets an app keep visible while it hides the others.
/// Raw values are `MBSystemItemIdentifier` of the private MenuBarClientCore framework (macOS 27.2).
public enum SystemItem: Int, CaseIterable, Codable, Sendable {
    case battery = 0, bluetooth, clock, displays, keyboard, volume, wifi, screenMirroring, controlCenter
}

/// What stays in the menu bar. Everything else is hidden and reachable from the Stowaway bar.
public struct MenuBarLayout: Codable, Equatable, Sendable {
    /// Apps whose icons stay in the menu bar.
    public var pinnedBundleIDs: [String]
    /// System icons that stay in the menu bar.
    public var systemItems: [SystemItem]

    public init(pinnedBundleIDs: [String], systemItems: [SystemItem]) {
        self.pinnedBundleIDs = pinnedBundleIDs
        self.systemItems = systemItems
    }

    public static let `default` = MenuBarLayout(pinnedBundleIDs: ["eu.exelban.Stats"], systemItems: [.clock, .controlCenter])

    public func isPinned(_ bundleID: String) -> Bool { pinnedBundleIDs.contains(bundleID) }

    public mutating func togglePin(_ bundleID: String) {
        if let i = pinnedBundleIDs.firstIndex(of: bundleID) { pinnedBundleIDs.remove(at: i) } else { pinnedBundleIDs.append(bundleID) }
    }

    public mutating func toggleSystemItem(_ item: SystemItem) {
        if let i = systemItems.firstIndex(of: item) { systemItems.remove(at: i) } else { systemItems.append(item) }
    }

    /// The allow-list for macOS: the app itself, the pinned apps and the app being revealed right now.
    public func allowedBundleIDs(own: String, revealing: String? = nil) -> [String] {
        var ids = [own] + pinnedBundleIDs
        if let revealing { ids.append(revealing) }
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }

    public var allowedSystemItemValues: [Int] { systemItems.map(\.rawValue).sorted() }
}
