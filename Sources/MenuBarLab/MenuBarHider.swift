// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import AppKit
import ObjectiveC
import os

/// Hides menu bar icons through the private `MBAssessmentModeAssertion` of MenuBarClientCore (macOS 27).
/// While an assertion is active, only the allowed apps and system items are drawn in the menu bar.
/// Invalidating it, quitting or crashing restores every icon (macOS drops the assertion with the connection).
@MainActor final class MenuBarHider {
    nonisolated private static let log = Logger(subsystem: "io.github.furcenzo.menubarlab", category: "hider")
    private static let loaded = dlopen("/System/Library/PrivateFrameworks/MenuBarClientCore.framework/MenuBarClientCore", RTLD_NOW) != nil

    private var assertion: NSObject?

    var isAvailable: Bool {
        Self.loaded && NSClassFromString("MBAssessmentModeConfiguration") != nil && NSClassFromString("MBAssessmentModeAssertion") != nil
    }

    var isActive: Bool { assertion != nil }

    /// Keeps only `bundleIDs` and `systemItems` (MBSystemItemIdentifier raw values) in the menu bar.
    func apply(bundleIDs: [String], systemItems: [Int]) {
        guard isAvailable,
              let configClass = NSClassFromString("MBAssessmentModeConfiguration"),
              let assertionClass = NSClassFromString("MBAssessmentModeAssertion") as? NSObject.Type else { return }
        let initSelector = NSSelectorFromString("initWithAllowedSystemItems:allowedBundleIdentifiers:")
        typealias InitFunction = @convention(c) (AnyObject, Selector, NSArray, NSArray) -> AnyObject
        guard let allocated = (configClass as AnyObject).perform(NSSelectorFromString("alloc"))?.takeUnretainedValue() else { return }
        let config = unsafeBitCast(class_getMethodImplementation(configClass, initSelector), to: InitFunction.self)(
            allocated, initSelector, systemItems.map(NSNumber.init(value:)) as NSArray, bundleIDs as NSArray)

        let newAssertion = assertionClass.init()
        let activateSelector = NSSelectorFromString("activateWithConfiguration:completionHandler:")
        typealias ActivateFunction = @convention(c) (AnyObject, Selector, AnyObject, @escaping @convention(block) @Sendable (NSError?) -> Void) -> Void
        unsafeBitCast(class_getMethodImplementation(assertionClass, activateSelector), to: ActivateFunction.self)(
            newAssertion, activateSelector, config) { error in
            if let error { Self.log.error("activate failed: \(error, privacy: .public)") }
        }
        // The new assertion first, then drop the old one, so icons don't flash in between.
        let old = assertion
        assertion = newAssertion
        old?.perform(NSSelectorFromString("invalidate"))
    }

    /// Shows every icon again.
    func showAll() {
        assertion?.perform(NSSelectorFromString("invalidate"))
        assertion = nil
    }
}
