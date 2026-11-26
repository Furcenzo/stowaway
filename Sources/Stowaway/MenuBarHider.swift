// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import AppKit
import ObjectiveC
import os

/// Hides menu bar icons through the private `MBAssessmentModeAssertion` of MenuBarClientCore (macOS 27).
/// While an assertion is active, only the allowed apps and system items are drawn in the menu bar.
/// Invalidating it, quitting or crashing restores every icon (macOS drops the assertion with the connection).
@MainActor final class MenuBarHider {
    nonisolated private static let log = Logger(subsystem: "io.github.furcenzo.stowaway", category: "hider")
    private static let loaded = dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore", RTLD_NOW) != nil

    private var assertion: NSObject?
    /// Counts assertions, so that an error of one that was already replaced or dropped by Stowaway is ignored.
    private var generation = 0

    var isAvailable: Bool {
        Self.loaded && NSClassFromString("MBAssessmentModeConfiguration") != nil && NSClassFromString("MBAssessmentModeAssertion") != nil
    }

    var isActive: Bool { assertion != nil }

    /// Keeps only `bundleIDs` and `systemItems` (MBSystemItemIdentifier raw values) in the menu bar.
    /// `onError` runs on the main actor when macOS refuses or cancels the active request.
    func apply(bundleIDs: [String], systemItems: [Int], onError: @escaping @MainActor (String) -> Void) {
        guard isAvailable,
              let configClass = NSClassFromString("MBAssessmentModeConfiguration"),
              let assertionClass = NSClassFromString("MBAssessmentModeAssertion") as? NSObject.Type else { return }
        let initSelector = NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:")
        typealias InitFunction = @convention(c) (AnyObject, Selector, NSArray, NSArray) -> AnyObject
        guard let allocated = (configClass as AnyObject).perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() else { return }
        let config = unsafeBitCast(class_getMethodImplementation(configClass, initSelector), to: InitFunction.self)(
            allocated, initSelector, systemItems.map(NSNumber.init(value:)) as NSArray, bundleIDs as NSArray)

        generation += 1
        let current = generation
        let newAssertion = assertionClass.init()
        // MenuBarAgent drops the old restriction at once but applies the new one only ~150 ms later, so the old one
        // stays until the new one is active (or failed), else every icon flashes in between. 1 s at most, in case
        // macOS never answers.
        let retiring = Retiring(assertion)
        assertion = newAssertion
        let started = ContinuousClock.now
        let activateSelector = NSSelectorFromString("activateWithConfiguration:completionHandler:")
        typealias ActivateFunction = @convention(c) (AnyObject, Selector, AnyObject, @escaping @convention(block) @Sendable (NSError?) -> Void) -> Void
        unsafeBitCast(class_getMethodImplementation(assertionClass, activateSelector), to: ActivateFunction.self)(
            newAssertion, activateSelector, config) { [weak self] error in
            let text = error.map { String(describing: $0) }
            let description = error?.localizedDescription
            Task { @MainActor in
                retiring.invalidate()
                guard let text, let description else {
                    Self.log.notice("activated in \(Int(started.duration(to: .now) / .milliseconds(1)), privacy: .public) ms")
                    return
                }
                // Replacing an assertion whose activation is still pending cancels it
                // (VisibilityRestrictionError.cancellation): that's Stowaway's own doing, not macOS refusing.
                guard let self, self.generation == current, self.assertion != nil else {
                    Self.log.notice("ignored error of a replaced assertion: \(text, privacy: .public)")
                    return
                }
                Self.log.error("activate failed: \(text, privacy: .public)")
                onError(description)
            }
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            retiring.invalidate()
        }
    }

    /// Shows every icon again.
    func showAll() {
        generation += 1
        assertion?.perform(NSSelectorFromString("invalidate"))
        assertion = nil
    }
}

/// An assertion that was replaced, invalidated once when its successor is active.
private final class Retiring: @unchecked Sendable {
    private var assertion: NSObject?

    init(_ assertion: NSObject?) {
        self.assertion = assertion
    }

    /// Only called on the main actor.
    func invalidate() {
        assertion?.perform(NSSelectorFromString("invalidate"))
        assertion = nil
    }
}
