// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import MenuBarLabCore
import SwiftUI

@main
struct MenuBarLabApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Hello!")
                .font(.largeTitle)
            Text("Version \(AppInfo.version)")
                .foregroundStyle(.secondary)
        }
        .padding(40)
    }
}
