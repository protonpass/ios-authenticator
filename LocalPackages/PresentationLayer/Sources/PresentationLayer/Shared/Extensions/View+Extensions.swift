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

import CommonUtilities
import SwiftUI

// MARK: - View builder functions

public extension View {
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

    @ViewBuilder
    func resizableSheet() -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            presentationSizing(.form.sticky())
        }
        #else
        self
        #endif
    }

    // periphery:ignore
    /// Show as confirmation dialog on iPhone, as alert on iPad because iPad doesn't support confirmation dialog
    @ViewBuilder
    func adaptiveConfirmationDialog(_ title: LocalizedStringKey,
                                    isPresented: Binding<Bool>,
                                    @ViewBuilder actions: () -> some View) -> some View {
        if AppConstants.isPhone {
            confirmationDialog(title, isPresented: isPresented, actions: actions)
        } else {
            alert(title, isPresented: isPresented, actions: actions)
        }
    }

    func errorMessageAlert(_ message: Binding<String?>) -> some View {
        alert(Text("An error occurred", bundle: .module),
              isPresented: message.mappedToBool(),
              actions: {},
              message: { Text(verbatim: message.wrappedValue ?? "") })
    }
}

// MARK: - Common UI modification tools

public extension View {
    func plainListRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
    }

    // periphery:ignore
    func disableAnimations() -> some View {
        transaction { $0.animation = nil }
    }

    func mainBackground() -> some View {
        modifier(MainBackgroundColor())
    }

    func fullScreenMainBackground() -> some View {
        ZStack {
            Color.clear
                .mainBackground()
                .ignoresSafeArea()
            self
        }
    }

    func textShadow() -> some View {
        shadow(color: .textShadow, radius: 1, x: 0, y: 2)
    }

    func passDynamicFont(size: CGFloat = 14,
                         textStyle: UIFont.TextStyle = .body,
                         weight: Font.Weight = .regular) -> some View {
        font(.system(size: UIFontMetrics(forTextStyle: textStyle).scaledValue(for: size), weight: weight))
    }
}

// MARK: - Non exposed extension

extension View {
    func coloredBackgroundButton(_ shape: some Shape) -> some View {
        background(shape
            .fill(.shadow(.inner(color: .white.opacity(0.25), radius: 2, x: 0, y: 1)))
            .foregroundStyle(LinearGradient(stops:
                [
                    Gradient.Stop(color: Color(red: 0.45, green: 0.31, blue: 1), location: 0.00),
                    Gradient.Stop(color: Color(red: 0.27, green: 0.19, blue: 0.6), location: 1.00)
                ],
                startPoint: UnitPoint(x: 0.5, y: 0),
                endPoint: UnitPoint(x: 0.5, y: 1))))
            .clipShape(shape)
            .shadow(color: Color(red: 0.6, green: 0.37, blue: 1).opacity(0.25), radius: 12, x: 0, y: 1)
            .overlay(shape.stroke(Color.buttonShadowBorder, lineWidth: 0.5))
    }

    /// Dim the background and show a spinner in the middle of the view
    /// - Parameters:
    ///   - isShowing: Whether to show the spinner or not
    ///   - disableWhenShowing: Whether to disable the view while showing the spinner or not
    ///   - size: The size of the spinner
    func showSpinner(_ isShowing: Bool,
                     disableWhenShowing: Bool = true,
                     size: ControlSize = .large) -> some View {
        overlay {
            if isShowing {
                Color.black
                    .opacity(0.3)
                    .ignoresSafeArea()
                ProgressView()
                    .controlSize(size)
            }
        }
        .disabled(disableWhenShowing && isShowing)
        .animation(.default, value: isShowing)
    }

    /// Applies `.searchFocused` modifier only on iOS 18+
    @ViewBuilder
    func searchFocusable(_ isFocused: FocusState<Bool>.Binding) -> some View {
        if #available(iOS 18, macOS 15.0, visionOS 2.0, *) {
            self.searchFocused(isFocused)
        } else {
            self
        }
    }
}
