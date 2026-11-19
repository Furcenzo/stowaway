// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import SwiftUI
import UniformTypeIdentifiers

/// The bar under the Stowaway icon: one button per hidden menu bar icon. Icons are reordered by dragging;
/// a line between the icons shows where the dragged one lands.
struct BarView: View {
    @ObservedObject var controller: AppController
    @State private var dragged: String?
    /// Index of the tile in front of which the dragged app would land (tiles.count = at the end).
    @State private var insertion: Int?

    private static let tileSize: CGFloat = 30
    private static let spacing: CGFloat = 4

    /// One tile per icon: an app with several icons has several tiles.
    private var tiles: [(app: MenuBarApp, index: Int)] {
        controller.hiddenApps.flatMap { app in (0..<app.itemCount).map { (app, $0) } }
    }

    var body: some View {
        Group {
            if let problem = controller.problem {
                Text(problem.message)
                    .frame(maxWidth: 260)
            } else if !MenuBarItems.isTrusted {
                Text("Stowaway needs Accessibility to open hidden icons.")
                    .frame(maxWidth: 260)
            } else if controller.hiddenApps.isEmpty {
                Text("No hidden icons")
                    .foregroundStyle(.secondary)
            } else {
                bar
            }
        }
        .padding(8)
        .onDisappear {
            Tooltip.shared.hide()
            dragged = nil
            insertion = nil
        }
    }

    private var bar: some View {
        let tiles = tiles
        return HStack(spacing: Self.spacing) {
            ForEach(Array(tiles.enumerated()), id: \.offset) { _, tile in
                tileView(tile.app, index: tile.index)
            }
        }
        .overlay(alignment: .leading) {
            if let insertion {
                // In the middle of the gap in front of tile `insertion`.
                let x = CGFloat(insertion) * (Self.tileSize + Self.spacing) - Self.spacing / 2
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 2, height: Self.tileSize - 4)
                    .offset(x: min(max(x - 1, 0), CGFloat(tiles.count) * (Self.tileSize + Self.spacing) - Self.spacing - 2))
            }
        }
        .onDrop(of: [.text], delegate: BarDropDelegate(tiles: tiles, dragged: $dragged, insertion: $insertion) { id, target in
            controller.moveInBar(id, before: target)
        })
    }

    private func tileView(_ app: MenuBarApp, index: Int) -> some View {
        Button {
            Tooltip.shared.hide()
            controller.open(app, item: index)
        } label: {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 22, height: 22)
                .overlay(alignment: .bottomTrailing) {
                    if app.itemCount > 1 {
                        Text(verbatim: "\(index + 1)")
                            .font(.system(size: 8, weight: .bold))
                            .padding(1)
                            .background(.background, in: Circle())
                    }
                }
                .padding(4)
                .frame(width: Self.tileSize, height: Self.tileSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(dragged == app.bundleID && insertion != nil ? 0.4 : 1)
        .onDrag {
            Tooltip.shared.hide()
            dragged = app.bundleID
            return NSItemProvider(object: app.bundleID as NSString)
        } preview: {
            Image(nsImage: app.icon).resizable().frame(width: 22, height: 22)
        }
        .onHover { inside in
            if NSEvent.pressedMouseButtons == 0 { dragged = nil } // a drag dropped outside the bar
            if inside && dragged == nil { Tooltip.shared.show(app.name) } else { Tooltip.shared.hide() }
        }
    }
}

/// Moves the dragged app (not copies it, so there is no "+" at the cursor) to the gap under the mouse.
private struct BarDropDelegate: DropDelegate {
    let tiles: [(app: MenuBarApp, index: Int)]
    @Binding var dragged: String?
    @Binding var insertion: Int?
    let move: (_ id: String, _ before: String?) -> Void

    private func gap(at location: CGPoint) -> Int {
        let step: CGFloat = 34 // tile + spacing
        return min(max(Int((location.x / step).rounded()), 0), tiles.count)
    }

    func validateDrop(info: DropInfo) -> Bool { dragged != nil }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        insertion = gap(at: info.location)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) { insertion = nil }

    func performDrop(info: DropInfo) -> Bool {
        defer { dragged = nil; insertion = nil }
        guard let id = dragged else { return false }
        // The first tile from the gap on that belongs to another app; none = to the end.
        let target = tiles[gap(at: info.location)...].first { $0.app.bundleID != id }?.app.bundleID
        move(id, target)
        return true
    }
}
