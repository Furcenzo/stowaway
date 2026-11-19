// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import AppKit
import SwiftUI

/// README screenshots (scripts/screenshots.sh): the bar drawn by the app itself with sample apps,
/// so no real icons, menu bar or desktop end up in the pictures.
@MainActor enum Snapshot {
    private static let samples: [(name: String, symbol: String, color: NSColor, items: Int)] = [
        ("Cloud Sync", "cloud.fill", .systemBlue, 1),
        ("VPN", "lock.shield.fill", .systemGreen, 1),
        ("Music", "music.note", .systemPink, 1),
        ("Clipboard", "doc.on.clipboard.fill", .systemOrange, 1),
        ("Network Monitor", "network", .systemTeal, 2),
        ("Timer", "timer", .systemPurple, 1),
        ("Weather", "cloud.sun.fill", .systemIndigo, 1),
    ]

    static func render(controller: AppController, to folder: URL) {
        controller.showSample(samples.enumerated().map { index, sample in
            MenuBarApp(bundleID: "sample.\(index)", name: sample.name, pid: 0, itemCount: sample.items,
                       sampleIcon: icon(sample.symbol, sample.color))
        })
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for scheme in [ColorScheme.light, .dark] {
            let tiles = controller.hiddenApps.flatMap { app in (0..<app.itemCount).map { (app, $0) } }
            let view = HStack(spacing: 4) {
                ForEach(Array(tiles.enumerated()), id: \.offset) { _, tile in BarView.tile(tile.0, index: tile.1) }
            }
                .padding(8)
                .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(nsColor: .separatorColor)))
                .padding(12)
                .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.cgImage,
                  let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { continue }
            try? data.write(to: folder.appendingPathComponent("bar-\(scheme == .light ? "light" : "dark").png"))
        }
    }

    /// An app-like icon: a white symbol on a colored rounded square.
    private static func icon(_ symbol: String, _ color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
            color.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 4, dy: 4), xRadius: 13, yRadius: 13).fill()
            let config = NSImage.SymbolConfiguration(pointSize: 30, weight: .semibold).applying(.init(paletteColors: [.white]))
            if let glyph = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
                glyph.draw(in: NSRect(x: rect.midX - glyph.size.width / 2, y: rect.midY - glyph.size.height / 2,
                                      width: glyph.size.width, height: glyph.size.height))
            }
            return true
        }
    }
}
