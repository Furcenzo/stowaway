// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import PackageDescription

let package = Package(
    name: "MenuBarLab",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "MenuBarLab", targets: ["MenuBarLab"]),
    ],
    targets: [
        // Pure logic – no UI, tested.
        .target(name: "MenuBarLabCore"),
        .executableTarget(
            name: "MenuBarLab",
            dependencies: ["MenuBarLabCore"],
            // Localizable.strings files are copied into the .app by scripts/build-app.sh
            exclude: ["Resources"]
        ),
        .testTarget(name: "MenuBarLabCoreTests", dependencies: ["MenuBarLabCore"]),
    ]
)
