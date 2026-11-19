// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import Foundation

/// How many menu bar icons each app has, as last seen. macOS 27 tells nothing about hidden icons
/// (many apps even drop their AXExtrasMenuBar), so the bar lists the apps from this memory.
public struct KnownItems: Codable, Equatable, Sendable {
    public private(set) var counts: [String: Int]

    public init(counts: [String: Int] = [:]) {
        self.counts = counts
    }

    /// Remembers what is visible now. Apps not in `seen` keep their last count (they may just be hidden).
    public mutating func learn(_ seen: [String: Int]) {
        for (id, count) in seen where count > 0 { counts[id] = count }
    }

    public func count(of bundleID: String) -> Int { counts[bundleID] ?? 0 }

    /// The remembered apps among `running`, in the order of `running`.
    public func apps(among running: [String]) -> [String] {
        running.filter { count(of: $0) > 0 }
    }
}
