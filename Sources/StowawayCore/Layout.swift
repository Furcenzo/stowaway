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
    /// Order of the apps in the Stowaway bar (bundle IDs); apps not in it follow in the order they come.
    public var barOrder: [String]

    public init(pinnedBundleIDs: [String], systemItems: [SystemItem], barOrder: [String] = []) {
        self.pinnedBundleIDs = pinnedBundleIDs
        self.systemItems = systemItems
        self.barOrder = barOrder
    }

    private enum CodingKeys: String, CodingKey { case pinnedBundleIDs, systemItems, barOrder }

    // Settings saved by older versions have no barOrder.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pinnedBundleIDs = try container.decode([String].self, forKey: .pinnedBundleIDs)
        systemItems = try container.decode([SystemItem].self, forKey: .systemItems)
        barOrder = try container.decodeIfPresent([String].self, forKey: .barOrder) ?? []
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
    /// `ids` (e.g. sorted by name) in the bar order.
    public func sortedForBar(_ ids: [String]) -> [String] {
        let present = Set(ids)
        let ordered = barOrder.filter { present.contains($0) }
        let known = Set(ordered)
        return ordered + ids.filter { !known.contains($0) }
    }

    /// Moves `id` in front of `target` in the bar showing `ids`; `target` nil moves it to the end.
    public mutating func move(_ id: String, before target: String?, among ids: [String]) {
        guard id != target else { return }
        var order = sortedForBar(ids).filter { $0 != id }
        if let target, let index = order.firstIndex(of: target) { order.insert(id, at: index) } else { order.append(id) }
        let shown = Set(order)
        barOrder = order + barOrder.filter { !shown.contains($0) } // keep the place of apps not running now
    }

    public func allowedBundleIDs(own: String, revealing: String? = nil) -> [String] {
        var ids = [own] + pinnedBundleIDs
        if let revealing { ids.append(revealing) }
        var seen = Set<String>()
        return ids.filter { seen.insert($0).inserted }
    }

    public var allowedSystemItemValues: [Int] { systemItems.map(\.rawValue).sorted() }
}
