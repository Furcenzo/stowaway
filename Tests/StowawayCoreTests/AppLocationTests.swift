// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import StowawayCore
import Testing

@Suite struct AppLocationTests {
    @Test func applicationsFolder() {
        #expect(AppLocation.canKeepIcon(bundlePath: "/Applications/Stats.app"))
        #expect(AppLocation.canKeepIcon(bundlePath: "/Applications/Utilities/Tool.app"))
        #expect(AppLocation.canKeepIcon(bundlePath: "/System/Library/CoreServices/TextInputMenuAgent.app"))
    }

    @Test func elsewhere() {
        #expect(!AppLocation.canKeepIcon(bundlePath: "/Users/someone/Applications/Example.app"))
        #expect(!AppLocation.canKeepIcon(bundlePath: "/Users/someone/Projects/Example/build/Example.app"))
        #expect(!AppLocation.canKeepIcon(bundlePath: "/ApplicationsExtra/Example.app"))
        #expect(!AppLocation.canKeepIcon(bundlePath: "/Applications/../tmp/Example.app"))
    }

    @Test func unknownPath() {
        #expect(AppLocation.canKeepIcon(bundlePath: nil))
    }
}
