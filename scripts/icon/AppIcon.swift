// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo
//
// Draws the Stowaway app icon as a 1024 × 1024 PNG. Placeholder from mac-app-kit: the first letter of the
// name on a blue rounded square – replace the drawing with the real icon.
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
color(0x2F6FE0).setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: color(0x4C8DF6), ending: color(0x1F4FB8))!.draw(in: shape, angle: -90)

// The first letter of the app name.
let letter = "S" as NSString
let font = NSFont.systemFont(ofSize: 520, weight: .bold)
let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
let textSize = letter.size(withAttributes: attributes)
letter.draw(at: NSPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2), withAttributes: attributes)

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
