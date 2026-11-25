// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import Testing
@testable import StowawayCore

@Suite struct HidingCheckTests {
    @Test func workingHidingHasNoProblem() {
        #expect(HidingCheck.problem(visible: ["own": 1, "stats": 6], own: "own", expectedHidden: ["a", "b"]) == nil)
    }

    @Test func missingOwnIconIsAProblem() {
        #expect(HidingCheck.problem(visible: ["stats": 6], own: "own", expectedHidden: ["a"]) == .ownIconHidden)
    }

    @Test func emptyMenuBarIsNotAReading() {
        #expect(HidingCheck.problem(visible: [:], own: "own", expectedHidden: ["a"]) == nil)
    }

    @Test func nothingHiddenIsAProblem() {
        #expect(HidingCheck.problem(visible: ["own": 1, "a": 1, "b": 2], own: "own", expectedHidden: ["a", "b"]) == .notHidden)
    }

    @Test func oneAppStayingVisibleIsTolerated() {
        #expect(HidingCheck.problem(visible: ["own": 1, "a": 1], own: "own", expectedHidden: ["a", "b"]) == nil)
        #expect(HidingCheck.problem(visible: ["own": 1], own: "own", expectedHidden: []) == nil)
    }
}
