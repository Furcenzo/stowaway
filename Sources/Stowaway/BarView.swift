// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import SwiftUI

/// The bar under the Stowaway icon: one button per hidden menu bar icon.
struct BarView: View {
    @ObservedObject var controller: AppController
    /// Name of the app under the mouse, shown below the icons (tooltips don't appear in a popover of a background app).
    @State private var hovered: String?

    var body: some View {
        Group {
            if !MenuBarItems.isTrusted {
                Text("Stowaway needs Accessibility to open hidden icons.")
                    .frame(maxWidth: 260)
            } else if controller.hiddenApps.isEmpty {
                Text("No hidden icons")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        ForEach(controller.hiddenApps) { app in
                            ForEach(0..<app.itemCount, id: \.self) { index in
                                Button {
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
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .onHover { inside in
                                    if inside { hovered = app.name } else if hovered == app.name { hovered = nil }
                                }
                            }
                        }
                    }
                    Text(verbatim: hovered ?? " ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
        }
        .padding(8)
    }
}
