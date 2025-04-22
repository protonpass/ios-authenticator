//
// Router.swift
// Proton Authenticator - Created on 10/02/2025.
// Copyright (c) 2025 Proton Technologies AG
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

// periphery:ignore:all

import Models
import SwiftUI

enum RouterDestination: Hashable {
    case appearance
}

public enum SheetDestination: Hashable, Identifiable {
    public var id: Int { hashValue }

    case createEditEntry(EntryUiModel?)
    case settings
}

public enum FullScreenDestination: Hashable, Identifiable {
    public var id: Int { hashValue }

    #if os(iOS)
    case qrCodeScanner
    #endif
}

@MainActor
@Observable
final class Router {
    var path = NavigationPath()

    var presentedSheet: SheetDestination?
    var presentedFullscreenSheet: FullScreenDestination?

    func navigate(to: RouterDestination) {
        path.append(to)
    }

    func popToRoot() {
        path.removeLast(path.count)
    }

    func back(to numberOfScreen: Int = 1) {
        path.removeLast(numberOfScreen)
    }
}

struct RouterEmbeded: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationDestination(for: RouterDestination.self) { destination in
                switch destination {
                case .appearance:
                    Text("appeareance")
                }
            }
    }
}

public extension View {
    var routingProvided: some View {
        modifier(RouterEmbeded())
    }

    func sheetDestinations(_ item: Binding<SheetDestination?>) -> some View {
        sheet(item: item) { destination in
            switch destination {
            case let .createEditEntry(entry):
                CreateEditEntryView(entry: entry)
                    .resizableSheet()
            case .settings:
                SettingsView()
                    .resizableSheet()
            }
        }
    }

    func fullScreenDestination(_ item: Binding<FullScreenDestination?>) -> some View {
        fullScreenCover(item: item) { destination in
            switch destination {
            #if os(iOS)
            case .qrCodeScanner:
                ScannerView()
            #endif
            }
        }
    }
}
