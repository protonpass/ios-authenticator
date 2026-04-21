//
// URL+Extensions.swift
// Proton Authenticator - Created on 02/03/2026.
// Copyright (c) 2026 Proton Technologies AG
//
// This file is part of Proton Authenticator.
//
// Proton Authenticator is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Authenticator is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Authenticator. If not, see https://www.gnu.org/licenses/.

import Foundation

// MARK: - Security-scoped bookmark options for iOS apps running on Mac

///
/// `.withSecurityScope` is marked @available(iOS, unavailable) in the SDK even though the
/// underlying macOS sandbox requires it when an iOS binary runs on Apple Silicon ("Designed
/// for iPad"). We expose the constants via their stable raw values from NSURLBookmark.h so
/// call-sites can pass them without a compile-time error.
///
///   NSURLBookmarkCreationWithSecurityScope  = 1 << 11  (NSURL.h)
///   NSURLBookmarkResolutionWithSecurityScope = 1 << 10  (NSURL.h)
public extension URL.BookmarkCreationOptions {
    /// Equivalent to `NSURLBookmarkCreationWithSecurityScope`.
    /// Use only when `ProcessInfo.processInfo.isiOSAppOnMac` is true.
    static let macSecurityScope = URL.BookmarkCreationOptions(rawValue: 1 << 11)
}

public extension URL.BookmarkResolutionOptions {
    /// Equivalent to `NSURLBookmarkResolutionWithSecurityScope`.
    /// Use only when `ProcessInfo.processInfo.isiOSAppOnMac` is true.
    static let macSecurityScope = URL.BookmarkResolutionOptions(rawValue: 1 << 10)
}

public extension URL {
    func withSecurityScopedAccess<T>(body: (URL) throws -> T) rethrows -> T {
        let didStart = startAccessingSecurityScopedResource()
        defer {
            if didStart {
                self.stopAccessingSecurityScopedResource()
            }
        }
        return try body(self)
    }
}
