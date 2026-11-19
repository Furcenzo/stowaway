// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo
//
// Draws the Stowaway app icon as a 1024 × 1024 PNG: a menu bar strip at the top, two app icons dropping from it
// into a suitcase – the icons stowed away out of the menu bar. The suitcase matches the menu bar icon.
// Run via scripts/make-icon.sh (`swift scripts/icon/AppIcon.swift <output.png>`), which also builds the .icns.

import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Background: macOS icon shape (824 pt body on a 1024 canvas) with a soft shadow.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 28
shadow.shadowColor = color(0x000000, 0.3)
shadow.set()
color(0x1B3C8F).setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: color(0x4A8EF5), ending: color(0x1B3C8F))!.draw(in: shape, angle: -90)
shape.addClip()

/// An app icon: a white symbol on a colored rounded square, turned by `rotation` degrees.
func appIcon(_ rect: NSRect, _ symbol: String, _ fill: UInt32, rotation: CGFloat, alpha: CGFloat) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: rect.midX, yBy: rect.midY)
    transform.rotate(byDegrees: rotation)
    transform.concat()
    let local = NSRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height)
    color(fill, alpha).setFill()
    NSBezierPath(roundedRect: local, xRadius: rect.width * 0.23, yRadius: rect.width * 0.23).fill()
    let config = NSImage.SymbolConfiguration(pointSize: rect.width * 0.48, weight: .bold)
        .applying(.init(paletteColors: [color(0xFFFFFF, alpha)]))
    if let glyph = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        glyph.draw(in: NSRect(x: -glyph.size.width / 2, y: -glyph.size.height / 2,
                              width: glyph.size.width, height: glyph.size.height))
    }
    NSGraphicsContext.restoreGraphicsState()
}

// The menu bar: a light strip with a few icons on the right.
color(0xFFFFFF, 0.9).setFill()
NSBezierPath(rect: NSRect(x: 100, y: 770, width: 824, height: 70)).fill()
for (index, x) in [560.0, 630, 700, 770].enumerated() {
    color(0x1B2A44, index == 0 ? 0.9 : 0.5).setFill()
    NSBezierPath(roundedRect: NSRect(x: x, y: 788, width: 40, height: 34), xRadius: 9, yRadius: 9).fill()
}

// Two icons on their way down.
appIcon(NSRect(x: 360, y: 610, width: 110, height: 110), "cloud.fill", 0x3B82F6, rotation: -14, alpha: 0.95)
appIcon(NSRect(x: 530, y: 560, width: 100, height: 100), "music.note", 0xEF4469, rotation: 10, alpha: 0.9)

// The suitcase: handle, body with a shadow, two straps and the lid seam.
let suitcase = NSRect(x: 252, y: 200, width: 520, height: 330)
let handleWidth = suitcase.width * 0.3, handleHeight = suitcase.height * 0.22
let handle = NSBezierPath(roundedRect: NSRect(x: suitcase.midX - handleWidth / 2, y: suitcase.maxY - 20,
                                              width: handleWidth, height: handleHeight + 20),
                          xRadius: handleHeight * 0.55, yRadius: handleHeight * 0.55)
handle.lineWidth = suitcase.width * 0.055
color(0x5C3416).setStroke()
handle.stroke()

let case_ = NSBezierPath(roundedRect: suitcase, xRadius: suitcase.width * 0.12, yRadius: suitcase.width * 0.12)
NSGraphicsContext.saveGraphicsState()
let caseShadow = NSShadow()
caseShadow.shadowOffset = NSSize(width: 0, height: -14)
caseShadow.shadowBlurRadius = 30
caseShadow.shadowColor = color(0x000000, 0.35)
caseShadow.set()
color(0xA8642C).setFill()
case_.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: color(0xE0A15E), ending: color(0xA8642C))!.draw(in: case_, angle: -90)

for x in [suitcase.minX + suitcase.width * 0.24, suitcase.maxX - suitcase.width * 0.24] {
    color(0x5C3416, 0.9).setFill()
    NSBezierPath(rect: NSRect(x: x - suitcase.width * 0.035, y: suitcase.minY, width: suitcase.width * 0.07,
                              height: suitcase.height)).fill()
}
let seam = NSBezierPath()
seam.move(to: NSPoint(x: suitcase.minX + 24, y: suitcase.maxY - suitcase.height * 0.16))
seam.line(to: NSPoint(x: suitcase.maxX - 24, y: suitcase.maxY - suitcase.height * 0.16))
seam.lineWidth = 8
color(0x5C3416, 0.45).setStroke()
seam.stroke()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
