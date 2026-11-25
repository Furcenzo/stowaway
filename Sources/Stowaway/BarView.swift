// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import SwiftUI
import UniformTypeIdentifiers

/// The bar under the Stowaway icon: one button per hidden menu bar icon, in rows when they don't fit on the
/// screen. Icons are reordered by dragging; a line between the icons shows where the dragged one lands.
struct BarView: View {
    @ObservedObject var controller: AppController
    @State private var dragged: String?
    /// Index of the tile in front of which the dragged app would land (tiles.count = at the end).
    @State private var insertion: Int?

    static let tileSize: CGFloat = 30
    static let spacing: CGFloat = 4
    static let padding: CGFloat = 8
    /// Distance between the starts of neighbouring tiles (and rows).
    static let step = tileSize + spacing

    /// One tile per icon: an app with several icons has several tiles.
    private var tiles: [(app: MenuBarApp, index: Int)] {
        controller.hiddenApps.flatMap { app in (0..<app.itemCount).map { (app, $0) } }
    }

    var body: some View {
        Group {
            if let problem = controller.problem {
                Text(problem.message)
                    .frame(maxWidth: 260)
            } else if !controller.isSample && !MenuBarItems.isTrusted {
                Text("Stowaway needs Accessibility to open hidden icons.")
                    .frame(maxWidth: 260)
            } else if controller.hiddenApps.isEmpty {
                Text("No hidden icons")
                    .foregroundStyle(.secondary)
            } else {
                bar
            }
        }
        .padding(Self.padding)
        .onDisappear {
            Tooltip.shared.hide()
            dragged = nil
            insertion = nil
        }
    }

    private var bar: some View {
        let tiles = tiles
        let columns = max(1, min(controller.barColumns, tiles.count))
        let rows = stride(from: 0, to: tiles.count, by: columns).map { Array(tiles.indices)[$0..<min($0 + columns, tiles.count)] }
        return VStack(alignment: .leading, spacing: Self.spacing) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Self.spacing) {
                    ForEach(row, id: \.self) { i in
                        tileView(tiles[i].app, index: tiles[i].index)
                    }
                }
            }
        }
        .overlay(alignment: .topLeading) {
            if let insertion {
                // In the middle of the gap in front of tile `insertion`; at the end of a row after its last tile.
                let row = insertion == tiles.count ? (tiles.count - 1) / columns : insertion / columns
                let column = insertion - row * columns
                let x = CGFloat(column) * Self.step - Self.spacing / 2
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 2, height: Self.tileSize - 4)
                    .offset(x: min(max(x - 1, 0), CGFloat(columns) * Self.step - Self.spacing - 2),
                            y: CGFloat(row) * Self.step + 2)
            }
        }
        .onDrop(of: [.text], delegate: BarDropDelegate(tiles: tiles, columns: columns, dragged: $dragged, insertion: $insertion) { id, target in
            controller.moveInBar(id, before: target)
        })
    }

    /// The icon of one tile (also drawn alone for the screenshots, where buttons don't render).
    static func tile(_ app: MenuBarApp, index: Int) -> some View {
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
            .frame(width: tileSize, height: tileSize)
            .contentShape(Rectangle())
    }

    private func tileView(_ app: MenuBarApp, index: Int) -> some View {
        Button {
            Tooltip.shared.hide()
            controller.open(app, item: index)
        } label: {
            Self.tile(app, index: index)
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
    let columns: Int
    @Binding var dragged: String?
    @Binding var insertion: Int?
    let move: (_ id: String, _ before: String?) -> Void

    private func gap(at location: CGPoint) -> Int {
        let lastRow = (tiles.count - 1) / columns
        let row = min(max(Int(location.y / BarView.step), 0), lastRow)
        let column = min(max(Int((location.x / BarView.step).rounded()), 0), columns)
        return min(row * columns + column, tiles.count)
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
