// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import AppKit

/// A tooltip next to the mouse. System tooltips don't appear in the popover of a background (agent) app.
@MainActor final class Tooltip {
    static let shared = Tooltip()

    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private var pending: DispatchWorkItem?

    private init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        let background = NSVisualEffectView()
        background.material = .toolTip
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 5
        label.font = .toolTipsFont(ofSize: 0)
        label.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -6),
            label.topAnchor.constraint(equalTo: background.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -3),
        ])
        panel.contentView = background
    }

    /// Shows `text` below the mouse after the usual tooltip delay.
    func show(_ text: String) {
        hide()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            label.stringValue = text
            let size = panel.contentView!.fittingSize
            let mouse = NSEvent.mouseLocation
            var origin = NSPoint(x: mouse.x, y: mouse.y - size.height - 18)
            if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) {
                origin.x = min(origin.x, screen.visibleFrame.maxX - size.width)
            }
            panel.setFrame(NSRect(origin: origin, size: size), display: true)
            panel.orderFrontRegardless()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func hide() {
        pending?.cancel()
        pending = nil
        panel.orderOut(nil)
    }
}
