// swift-tools-version: 6.0
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import PackageDescription

let package = Package(
    name: "Stowaway",
    platforms: [.macOS("27.0")],
    products: [
        .executable(name: "Stowaway", targets: ["Stowaway"]),
    ],
    targets: [
        // Pure logic – no UI, tested.
        .target(name: "StowawayCore"),
        .executableTarget(
            name: "Stowaway",
            dependencies: ["StowawayCore"],
            // Localizable.strings files are copied into the .app by scripts/build-app.sh
            exclude: ["Resources"]
        ),
        .testTarget(name: "StowawayCoreTests", dependencies: ["StowawayCore"]),
    ]
)
