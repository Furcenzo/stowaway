// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import SwiftUI

/// The bar under the Stowaway icon: one button per hidden menu bar icon.
struct BarView: View {
    @ObservedObject var controller: AppController

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
                HStack(spacing: 4) {
                    ForEach(controller.hiddenApps) { app in
                        ForEach(0..<app.itemCount, id: \.self) { index in
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
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            // Drag an icon onto another one to put it in that one's place.
                            .draggable(app.bundleID) {
                                Image(nsImage: app.icon).resizable().frame(width: 22, height: 22)
                            }
                            .dropDestination(for: String.self) { ids, _ in
                                guard let id = ids.first else { return false }
                                controller.moveInBar(id, onto: app.bundleID)
                                return true
                            }
                            .onHover { inside in
                                if inside { Tooltip.shared.show(app.name) } else { Tooltip.shared.hide() }
                            }
                        }
                    }
                }
            }
        }
        .padding(8)
        .onDisappear { Tooltip.shared.hide() }
    }
}
