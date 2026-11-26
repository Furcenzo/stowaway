// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import Testing
@testable import StowawayCore

@Suite struct RecoveryTests {
    @Test func pausesGrowAndRunOut() {
        var recovery = Recovery()
        let delays = (0..<6).map { _ in recovery.nextDelay(for: .refused) }
        #expect(delays == [1, 2, 4, 8, nil, nil])
        #expect(recovery.attempts == 4)
    }

    @Test func resetGivesEveryAttemptAgain() {
        var recovery = Recovery(delays: [1, 2])
        _ = recovery.nextDelay(for: .notHidden)
        _ = recovery.nextDelay(for: .notHidden)
        #expect(recovery.nextDelay(for: .notHidden) == nil)
        recovery.reset()
        #expect(recovery.nextDelay(for: .ownIconHidden) == 1)
    }

    @Test func missingAPIIsNotRetried() {
        var recovery = Recovery()
        #expect(recovery.nextDelay(for: .unavailable) == nil)
        #expect(recovery.attempts == 0)
    }

    @Test func onlyTheMissingAPIIsPermanent() {
        #expect(!HidingProblem.unavailable.isRecoverable)
        #expect(HidingProblem.refused.isRecoverable)
        #expect(HidingProblem.ownIconHidden.isRecoverable)
        #expect(HidingProblem.notHidden.isRecoverable)
    }
}
