// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import Foundation

/// Turning hiding on again after it stopped working: a few attempts with a growing pause, then give up.
/// After waking up or unlocking, MenuBarAgent may drop or refuse the request for a while.
public struct Recovery: Equatable, Sendable {
    /// Seconds to wait before each attempt.
    public let delays: [Double]
    public private(set) var attempts = 0

    public init(delays: [Double] = [1, 2, 4, 8]) {
        self.delays = delays
    }

    /// The pause before the next attempt, or nil when there's nothing left to try (or `problem` can't be fixed by trying again).
    public mutating func nextDelay(for problem: HidingProblem) -> Double? {
        guard problem.isRecoverable, attempts < delays.count else { return nil }
        defer { attempts += 1 }
        return delays[attempts]
    }

    /// Hiding works again: the next problem gets every attempt.
    public mutating func reset() {
        attempts = 0
    }
}

extension HidingProblem {
    /// A missing API won't come back by trying again; everything else may be a passing state of MenuBarAgent.
    public var isRecoverable: Bool { self != .unavailable }
}
