// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import SwiftUI

/// The bar under the MenuBarLab icon: one button per hidden menu bar icon.
struct BarView: View {
    @ObservedObject var controller: AppController

    var body: some View {
        Group {
            if !MenuBarItems.isTrusted {
                Text("MenuBarLab needs Accessibility to open hidden icons.")
                    .frame(maxWidth: 260)
            } else if controller.hiddenApps.isEmpty {
                Text("No hidden icons")
                    .foregroundStyle(.secondary)
            } else {
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
                            .help(Text(verbatim: app.name))
                        }
                    }
                }
            }
        }
        .padding(8)
    }
}
