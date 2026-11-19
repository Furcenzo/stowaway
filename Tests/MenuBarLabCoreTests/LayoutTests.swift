// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import Foundation
import Testing
@testable import MenuBarLabCore

@Suite struct LayoutTests {
    @Test func allowListStartsWithOwnAppAndHasNoDuplicates() {
        let layout = MenuBarLayout(pinnedBundleIDs: ["a", "own"], systemItems: [])
        #expect(layout.allowedBundleIDs(own: "own") == ["own", "a"])
        #expect(layout.allowedBundleIDs(own: "own", revealing: "a") == ["own", "a"])
        #expect(layout.allowedBundleIDs(own: "own", revealing: "b") == ["own", "a", "b"])
    }

    @Test func togglePinAddsAndRemoves() {
        var layout = MenuBarLayout(pinnedBundleIDs: [], systemItems: [])
        layout.togglePin("x")
        #expect(layout.isPinned("x"))
        layout.togglePin("x")
        #expect(!layout.isPinned("x"))
    }

    @Test func systemItemValuesMatchMacOS() {
        #expect(SystemItem.clock.rawValue == 2)
        #expect(SystemItem.controlCenter.rawValue == 8)
        var layout = MenuBarLayout(pinnedBundleIDs: [], systemItems: [.controlCenter, .clock])
        #expect(layout.allowedSystemItemValues == [2, 8])
        layout.toggleSystemItem(.clock)
        #expect(layout.allowedSystemItemValues == [8])
    }

    @Test func layoutSurvivesEncoding() throws {
        let data = try JSONEncoder().encode(MenuBarLayout.default)
        #expect(try JSONDecoder().decode(MenuBarLayout.self, from: data) == .default)
    }
}
