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

    /// Apps with menu bar icons (each app's own AXExtrasMenuBar, which exists whether the icon is hidden or not).
    static func apps() -> [MenuBarApp] {
        let own = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications.compactMap { app in
            guard let id = app.bundleIdentifier, id != own, !excluded.contains(id) else { return nil }
            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, 0.25)
            guard let extras = attribute(element, "AXExtrasMenuBar"),
                  let items = attribute(extras as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement], !items.isEmpty else { return nil }
            return MenuBarApp(bundleID: id, name: app.localizedName ?? id, pid: app.processIdentifier, itemCount: items.count)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Frames (screen coordinates, top left origin) of the icons of `pid` that MenuBarAgent shows right now, left to right.
    static func frames(of pid: pid_t) -> [CGRect] {
        guard let agent = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.MenuBarAgent").first,
              let screen = NSScreen.screens.first else { return [] }
        let element = AXUIElementCreateApplication(agent.processIdentifier)
        var frames: [CGRect] = []
        for window in attribute(element, kAXWindowsAttribute) as? [AXUIElement] ?? [] {
            for group in attribute(window, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
                guard let owner = (attribute(group, kAXChildrenAttribute) as? [AXUIElement])?.first else { continue }
                var ownerPid: pid_t = 0
                guard AXUIElementGetPid(owner, &ownerPid) == .success, ownerPid == pid,
                      (attribute(owner, kAXRoleAttribute) as? String) == kAXApplicationRole else { continue }
                let frame = frame(group)
                if frame.width > 0, frame.minX >= 0, frame.maxX <= screen.frame.width, !frames.contains(frame) { frames.append(frame) }
            }
        }
        return frames.sorted { $0.minX < $1.minX }
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
