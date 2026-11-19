// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import AppKit
import StowawayCore
import SwiftUI

/// The Stowaway icon: left click opens the bar with the hidden icons, right click the menu.
@MainActor final class AppController: NSObject, ObservableObject {
    @Published private(set) var apps: [MenuBarApp] = []
    @Published private(set) var layout: MenuBarLayout
    @Published private(set) var paused = false

    private let hider = MenuBarHider()
    private let ownID = Bundle.main.bundleIdentifier ?? "io.github.furcenzo.stowaway"
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var revealTask: Task<Void, Never>?
    private var known: KnownItems
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
        statusItem.button?.image = NSImage(systemSymbolName: "menubar.rectangle", accessibilityDescription: "Stowaway")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: BarView(controller: self))
        if !MenuBarItems.isTrusted { MenuBarItems.requestTrust() }
        // Everything is still visible at launch: remember which apps have icons before hiding them.
        learn(MenuBarItems.visibleCounts())
        applyLayout()
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
        if paused { hider.showAll(); return }
        hider.apply(bundleIDs: layout.allowedBundleIDs(own: ownID, revealing: revealing), systemItems: layout.allowedSystemItemValues)
    }

    private func learn(_ counts: [String: Int]) {
        known.learn(counts)
        if let data = try? JSONEncoder().encode(known) { UserDefaults.standard.set(data, forKey: Self.knownKey) }
    }

    /// A newly launched app's icon is hidden right away, so show it for a moment to learn whether it has one.
    private func probe(bundleID: String, pid: pid_t) {
        guard !paused, known.count(of: bundleID) == 0, !layout.isPinned(bundleID), bundleID != ownID else { return }
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
        if paused || !hider.isActive { learn(MenuBarItems.visibleCounts()) }
        apps = MenuBarItems.apps(known: known.counts)
    }

    private func makeMenu() -> NSMenu {
        refreshApps()
        let menu = NSMenu()
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
