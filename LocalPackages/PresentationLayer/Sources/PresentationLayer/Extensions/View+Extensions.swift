//
// View+Extensions.swift
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

import SwiftUI

public extension View {
    /// Applies the given transform if the given condition evaluates to `true`.
    /// - Parameters:
    ///   - condition: The condition to evaluate.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the condition is `true`.
    @ViewBuilder
    func `if`(_ condition: @autoclosure () -> Bool, transform: (Self) -> some View) -> some View {
        if condition() {
            transform(self)
        } else {
            self
        }
    }

    /// Applies the given transform if the given value is not nil.
    /// - Parameters:
    ///   - value: The optional value.
    ///   - transform: The transform to apply to the source `View`.
    /// - Returns: Either the original `View` or the modified `View` if the value is not nil.
    @ViewBuilder
    func `if`<T>(_ value: T?, transform: (Self, T) -> some View) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }
}

public extension View {
    func plainListRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
    }

    /// Show as confirmation dialog on iPhone, as alert on iPad because iPad doesn't support confirmation dialog
    @ViewBuilder
    func adaptiveConfirmationDialog(_ title: LocalizedStringKey,
                                    isPresented: Binding<Bool>,
                                    @ViewBuilder actions: () -> some View) -> some View {
        #if canImport(UIKit)
        if UIDevice.current.userInterfaceIdiom == .phone {
            confirmationDialog(title, isPresented: isPresented, actions: actions)
        } else {
            alert(title, isPresented: isPresented, actions: actions)
        }
        #else
        alert(title, isPresented: isPresented, actions: actions)
        #endif
    }
}
