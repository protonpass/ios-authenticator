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

import Models
import SwiftUI

public enum RouterDestination: Hashable {
    case appearance
}

public enum SheetDestination: Hashable, Identifiable {
    public var id: Int { hashValue }

    case createEditToken(Token?)
    case settings
    #if os(iOS)
    case barcodeScanner
    #endif
}

@MainActor
@Observable
final class Router {
    var path = NavigationPath()

    var presentedSheet: SheetDestination?

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

public struct RouterEmbeded: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .navigationDestination(for: RouterDestination.self) { destination in
                switch destination {
                case .appearance:
                    Text("appeareance")
//                    AppearanceView()
                }
            }
    }
}

public extension View {
    var routingProvided: some View {
        modifier(RouterEmbeded())
    }

    func withSheetDestinations(sheetDestinations: Binding<SheetDestination?>) -> some View {
        sheet(item: sheetDestinations) { destination in
            switch destination {
            case let .createEditToken(token):
                CreateEditTokenView(item: token)
            case .settings:
                SettingsView()
            #if os(iOS)
            case .barcodeScanner:
                Text("barcode scanner")

//                ScannerView()
            #endif
            }
        }
    }
}
