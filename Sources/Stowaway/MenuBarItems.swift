// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import AppKit
import ApplicationServices

/// A running app that has at least one icon in the menu bar.
struct MenuBarApp: Identifiable, Equatable {
    let bundleID: String
    let name: String
    let pid: pid_t
    let itemCount: Int
    var id: String { bundleID }
    var icon: NSImage { NSRunningApplication(processIdentifier: pid)?.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)! }
}

/// Reads the menu bar through Accessibility. In macOS 27 every icon is drawn by MenuBarAgent in one window;
/// its Accessibility tree has one group per icon with the owning app inside.
@MainActor enum MenuBarItems {
    /// Processes that draw the menu bar itself or whose icons can't be hidden as an app.
    private static let excluded: Set<String> = ["com.apple.MenuBarAgent", "com.apple.controlcenter", "com.apple.systemuiserver"]

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestTrust() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// Running apps with menu bar icons: the remembered ones (`known`, bundle ID → icon count) plus those that
    /// report icons through their own AXExtrasMenuBar (many apps drop it while their icon is hidden).
    static func apps(known: [String: Int]) -> [MenuBarApp] {
        let own = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard let id = app.bundleIdentifier, id != own, !excluded.contains(id) else { return nil }
            var count = known[id] ?? 0
            if count == 0 {
                let element = AXUIElementCreateApplication(app.processIdentifier)
                AXUIElementSetMessagingTimeout(element, 0.25)
                if let extras = attribute(element, "AXExtrasMenuBar") {
                    count = (attribute(extras as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement])?.count ?? 0
                }
            }
            guard count > 0 else { return nil }
            return MenuBarApp(bundleID: id, name: app.localizedName ?? id, pid: app.processIdentifier, itemCount: count)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Bundle ID → number of icons that MenuBarAgent shows right now.
    static func visibleCounts() -> [String: Int] {
        var counts: [String: Int] = [:]
        for (pid, frames) in visibleFrames() {
            guard let id = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier else { continue }
            counts[id, default: 0] += frames.count
        }
        return counts
    }

    /// Frames (screen coordinates, top left origin) of the icons of `pid` that MenuBarAgent shows right now, left to right.
    static func frames(of pid: pid_t) -> [CGRect] {
        visibleFrames()[pid] ?? []
    }

    /// The icons MenuBarAgent shows right now, by owning process, left to right.
    private static func visibleFrames() -> [pid_t: [CGRect]] {
        guard let agent = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first,
              let screen = NSScreen.screens.first else { return [:] }
        let element = AXUIElementCreateApplication(agent.processIdentifier)
        var result: [pid_t: [CGRect]] = [:]
        // MenuBarAgent has a window per display and Space with the same icons; the first one is enough.
        guard let window = (attribute(element, kAXWindowsAttribute) as? [AXUIElement])?.first else { return [:] }
        for group in attribute(window, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
            guard let owner = (attribute(group, kAXChildrenAttribute) as? [AXUIElement])?.first,
                  (attribute(owner, kAXRoleAttribute) as? String) == kAXApplicationRole else { continue }
            var pid: pid_t = 0
            guard AXUIElementGetPid(owner, &pid) == .success else { continue }
            let frame = frame(group)
            // Icons in macOS's own overflow are stacked at the overflow arrow; they still count.
            if frame.width > 0, frame.minX >= 0, frame.maxX <= screen.frame.width { result[pid, default: []].append(frame) }
        }
        return result.mapValues { $0.sorted { $0.minX < $1.minX } }
    }

    /// A real mouse click in the middle of `frame`; the cursor goes back where it was.
    static func click(_ frame: CGRect) {
        let point = CGPoint(x: frame.midX, y: frame.midY)
        let original = CGEvent(source: nil)?.location
        for type in [CGEventType.leftMouseDown, .leftMouseUp] {
            CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        }
        if let original { CGWarpMouseCursorPosition(original) }
    }

    /// IDs of the on-screen windows of `pid` above normal windows (menus, popovers, panels).
    static func floatingWindows(of pid: pid_t) -> Set<Int> {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(list.compactMap { window in
            guard (window[kCGWindowOwnerPID as String] as? Int).map(pid_t.init) == pid,
                  (window[kCGWindowLayer as String] as? Int ?? 0) > 0 else { return nil }
            return window[kCGWindowNumber as String] as? Int
        })
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private static func frame(_ element: AXUIElement) -> CGRect {
        var origin = CGPoint.zero, size = CGSize.zero
        if let value = attribute(element, kAXPositionAttribute) { AXValueGetValue(value as! AXValue, .cgPoint, &origin) }
        if let value = attribute(element, kAXSizeAttribute) { AXValueGetValue(value as! AXValue, .cgSize, &size) }
        return CGRect(origin: origin, size: size)
    }
}
