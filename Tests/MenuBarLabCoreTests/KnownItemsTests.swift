// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import Testing
@testable import MenuBarLabCore

@Suite struct KnownItemsTests {
    @Test func learnKeepsAppsThatAreNotVisibleNow() {
        var known = KnownItems()
        known.learn(["a": 1, "b": 2])
        known.learn(["a": 3])
        #expect(known.count(of: "a") == 3)
        #expect(known.count(of: "b") == 2)
        #expect(known.count(of: "c") == 0)
    }

    @Test func zeroCountsAreIgnored() {
        var known = KnownItems(counts: ["a": 1])
        known.learn(["a": 0, "b": 0])
        #expect(known.counts == ["a": 1])
    }

    @Test func appsAreFilteredByRunningInTheirOrder() {
        let known = KnownItems(counts: ["a": 1, "b": 1])
        #expect(known.apps(among: ["c", "b", "a"]) == ["b", "a"])
    }
}
