// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Furcenzo

import Foundation

public enum AppInfo {
    /// CFBundleShortVersionString of the running app ("dev" outside an app bundle, e.g. `swift run`).
    public static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}
