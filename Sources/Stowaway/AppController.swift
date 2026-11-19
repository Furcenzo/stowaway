// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import AppKit
import os
import StowawayCore
import SwiftUI

/// The Stowaway icon: left click opens the bar with the hidden icons, right click the menu.
@MainActor final class AppController: NSObject, ObservableObject {
    @Published private(set) var apps: [MenuBarApp] = []
    @Published private(set) var layout: MenuBarLayout
    @Published private(set) var paused = false
    /// Set when hiding doesn't work; every icon is visible then and nothing is hidden until "Try Again".
    @Published private(set) var problem: HidingProblem?

    private let hider = MenuBarHider()
    private let ownID = Bundle.main.bundleIdentifier ?? "io.github.furcenzo.stowaway"
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var revealTask: Task<Void, Never>?
    private var checkTask: Task<Void, Never>?
    private var known: KnownItems
    /// False until Accessibility is allowed and the icons are learned; nothing is hidden before that.
    private var started = false
    private static let log = Logger(subsystem: "io.github.furcenzo.stowaway", category: "controller")
    private static let layoutKey = "layout"
    private static let knownKey = "knownItems"

    var hiddenApps: [MenuBarApp] { apps.filter { !layout.isPinned($0.bundleID) } }

    override init() {
        if let data = UserDefaults.standard.data(forKey: Self.layoutKey),
           let saved = try? JSONDecoder().decode(MenuBarLayout.self, from: data) {
            layout = saved
        } else {
            layout = .default
        }
        if let data = UserDefaults.standard.data(forKey: Self.knownKey),
           let saved = try? JSONDecoder().decode(KnownItems.self, from: data) {
            known = saved
        } else {
            known = KnownItems()
        }
        super.init()
    }

    func start() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "Stowaway"
        statusItem.button?.image = NSImage(systemSymbolName: "suitcase", accessibilityDescription: "Stowaway")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: BarView(controller: self))
        if MenuBarItems.isTrusted {
            startHiding()
        } else {
            // Without Accessibility the icons can't be learned (or opened later), so hide nothing until it's allowed.
            MenuBarItems.requestTrust()
            Task { [weak self] in
                while !MenuBarItems.isTrusted { try? await Task.sleep(for: .seconds(2)) }
                self?.startHiding()
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let id = app.bundleIdentifier else { return }
            let pid = app.processIdentifier
            MainActor.assumeIsolated { self?.probe(bundleID: id, pid: pid) }
        }
    }

    func stop() {
        hider.showAll()
    }

    // MARK: - Hiding

    private func applyLayout(revealing: String? = nil) {
        guard started, problem == nil else { return }
        if paused { hider.showAll(); return }
        guard hider.isAvailable else { fail(.unavailable); return }
        hider.apply(bundleIDs: layout.allowedBundleIDs(own: ownID, revealing: revealing), systemItems: layout.allowedSystemItemValues) { [weak self] error in
            Self.log.error("hiding refused: \(error, privacy: .public)")
            self?.fail(.refused)
        }
        if revealing == nil { scheduleCheck() }
    }

    /// The private API may stop working in a macOS update: check the menu bar a moment later and give up loudly.
    private func scheduleCheck() {
        checkTask?.cancel()
        checkTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, !Task.isCancelled, hider.isActive, revealTask == nil,
                  let visible = MenuBarItems.visibleCounts() else { return }
            let allowed = Set(layout.allowedBundleIDs(own: ownID))
            let expectedHidden = MenuBarItems.apps(known: known.counts).map(\.bundleID).filter { !allowed.contains($0) }
            if let problem = HidingCheck.problem(visible: visible, own: ownID, expectedHidden: expectedHidden) { fail(problem) }
        }
    }

    private func fail(_ problem: HidingProblem) {
        guard self.problem == nil else { return }
        Self.log.error("hiding turned off: \(String(describing: problem), privacy: .public)")
        self.problem = problem
        revealTask?.cancel()
        hider.showAll()
        popover.performClose(nil)
        let alert = NSAlert()
        alert.messageText = String(localized: "Stowaway can't hide icons")
        alert.informativeText = problem.message
        alert.alertStyle = .warning
        NSApp.activate()
        alert.runModal()
    }

    @objc private func tryAgain() {
        problem = nil
        applyLayout()
    }

    /// Everything is still visible: remember which apps have icons, then hide them.
    private func startHiding() {
        Task { [weak self] in
            // Right after launch (or after a previous Stowaway quit) MenuBarAgent may still be redrawing: retry for 5 s.
            // While the menu bar can't be read at all (hidden by a full screen app), wait until it can.
            var counts: [String: Int] = [:]
            var attempts = 0
            while counts.isEmpty, !Task.isCancelled {
                if let visible = MenuBarItems.visibleCounts() {
                    counts = visible
                    attempts += 1
                    if attempts >= 10 { break }
                }
                if counts.isEmpty { try? await Task.sleep(for: .milliseconds(500)) }
            }
            Self.log.notice("learned \(counts.count, privacy: .public) apps, trusted \(MenuBarItems.isTrusted, privacy: .public)")
            guard let self else { return }
            started = true
            learn(counts)
            applyLayout()
        }
    }

    private func learn(_ counts: [String: Int]) {
        known.learn(counts)
        if let data = try? JSONEncoder().encode(known) { UserDefaults.standard.set(data, forKey: Self.knownKey) }
    }

    /// A newly launched app's icon is hidden right away, so show it for a moment to learn whether it has one.
    private func probe(bundleID: String, pid: pid_t) {
        guard started, !paused, known.count(of: bundleID) == 0, !layout.isPinned(bundleID), bundleID != ownID else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3)) // apps add their icon a moment after launch
            guard let self, revealTask == nil, !paused else { return }
            applyLayout(revealing: bundleID)
            for _ in 0..<15 {
                try? await Task.sleep(for: .milliseconds(100))
                let frames = MenuBarItems.frames(of: pid)
                if !frames.isEmpty { learn([bundleID: frames.count]); break }
            }
            if revealTask == nil { applyLayout() }
        }
    }

    private func saveLayout() {
        if let data = try? JSONEncoder().encode(layout) { UserDefaults.standard.set(data, forKey: Self.layoutKey) }
        applyLayout()
    }

    // MARK: - Opening a hidden icon

    /// Shows the app's icons for a moment, clicks the chosen one and hides them again once its menu is closed.
    func open(_ app: MenuBarApp, item index: Int = 0) {
        popover.performClose(nil)
        revealTask?.cancel()
        revealTask = Task { [weak self] in
            guard let self else { return }
            defer { if !Task.isCancelled { revealTask = nil } }
            if !paused && !layout.isPinned(app.bundleID) { applyLayout(revealing: app.bundleID) }
            defer { if !Task.isCancelled { applyLayout() } }
            // Wait (max 3 s) until macOS draws the icon.
            var frames: [CGRect] = []
            for _ in 0..<30 {
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
                frames = MenuBarItems.frames(of: app.pid)
                if frames.count >= min(app.itemCount, index + 1) { break }
            }
            guard !frames.isEmpty else { NSSound.beep(); return }
            learn([app.bundleID: frames.count])
            let before = MenuBarItems.floatingWindows(of: app.pid)
            MenuBarItems.click(frames[min(index, frames.count - 1)])
            // Keep the icon until its menu closes: wait max 2 s for the menu to appear, then max 5 min for it to close.
            var opened = false
            for step in 0..<3000 {
                try? await Task.sleep(for: .milliseconds(100))
                if Task.isCancelled { return }
                let open = !MenuBarItems.floatingWindows(of: app.pid).subtracting(before).isEmpty
                if open { opened = true } else if opened || step >= 20 { break }
            }
        }
    }

    // MARK: - Menu

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusItem.menu = makeMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            refreshApps()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func refreshApps() {
        if paused || !hider.isActive, let visible = MenuBarItems.visibleCounts() { learn(visible) }
        apps = MenuBarItems.apps(known: known.counts)
    }

    private func makeMenu() -> NSMenu {
        refreshApps()
        let menu = NSMenu()
        if let problem {
            let info = NSMenuItem(title: problem.message, action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
            let again = NSMenuItem(title: String(localized: "Try Again"), action: #selector(tryAgain), keyEquivalent: "")
            again.target = self
            menu.addItem(again)
            menu.addItem(.separator())
        }
        let keep = NSMenuItem(title: String(localized: "Keep in Menu Bar"), action: nil, keyEquivalent: "")
        let keepMenu = NSMenu()
        for app in apps {
            let item = NSMenuItem(title: app.name, action: #selector(togglePin(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = app.bundleID
            item.state = layout.isPinned(app.bundleID) ? .on : .off
            item.image = app.icon
            item.image?.size = NSSize(width: 16, height: 16)
            keepMenu.addItem(item)
        }
        keepMenu.addItem(.separator())
        for system in SystemItem.allCases {
            let item = NSMenuItem(title: system.title, action: #selector(toggleSystemItem(_:)), keyEquivalent: "")
            item.target = self
            item.tag = system.rawValue
            item.state = layout.systemItems.contains(system) ? .on : .off
            keepMenu.addItem(item)
        }
        keep.submenu = keepMenu
        menu.addItem(keep)

        let pause = NSMenuItem(title: String(localized: "Show All Icons"), action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        pause.state = paused ? .on : .off
        menu.addItem(pause)

        if !MenuBarItems.isTrusted {
            menu.addItem(.separator())
            let access = NSMenuItem(title: String(localized: "Allow Accessibility…"), action: #selector(openAccessibilitySettings), keyEquivalent: "")
            access.target = self
            menu.addItem(access)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Quit Stowaway"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func togglePin(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        layout.togglePin(id)
        saveLayout()
    }

    @objc private func toggleSystemItem(_ sender: NSMenuItem) {
        guard let item = SystemItem(rawValue: sender.tag) else { return }
        layout.toggleSystemItem(item)
        saveLayout()
    }

    @objc private func togglePause() {
        paused.toggle()
        applyLayout()
    }

    @objc private func openAccessibilitySettings() {
        MenuBarItems.requestTrust()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

extension HidingProblem {
    var message: String {
        switch self {
        case .unavailable: String(localized: "This version of macOS doesn't let Stowaway hide icons. All icons stay visible.")
        case .refused: String(localized: "macOS refused to hide the icons. All icons are visible again.")
        case .ownIconHidden: String(localized: "Move Stowaway to the Applications folder, otherwise macOS hides its own icon too. All icons are visible again.")
        case .notHidden: String(localized: "macOS didn't hide the icons. All icons are visible again.")
        }
    }
}

extension SystemItem {
    var title: String {
        switch self {
        case .battery: String(localized: "Battery")
        case .bluetooth: String(localized: "Bluetooth")
        case .clock: String(localized: "Clock")
        case .displays: String(localized: "Displays")
        case .keyboard: String(localized: "Keyboard")
        case .volume: String(localized: "Sound")
        case .wifi: String(localized: "Wi-Fi")
        case .screenMirroring: String(localized: "Screen Mirroring")
        case .controlCenter: String(localized: "Control Center")
        }
    }
}
