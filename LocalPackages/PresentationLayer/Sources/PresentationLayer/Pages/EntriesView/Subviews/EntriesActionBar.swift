//
// EntriesActionBar.swift
// Proton Authenticator - Created on 17/02/2026.
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

import CommonUtilities
import SwiftUI

struct EntriesActionBar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var query: String
    let cleanSearch: () -> Void
    var searchFieldFocus: FocusState<Bool>.Binding
    let onAddNewCode: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            searchBar
            AddEntryButton(size: 42, action: onAddNewCode)
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.bar)
        .background(LinearGradient(stops:
            [
                Gradient.Stop(color: .black.opacity(0.5), location: 0.00),
                Gradient.Stop(color: .black.opacity(0), location: 1.00)
            ],
            startPoint: UnitPoint(x: 0.5, y: 1),
            endPoint: UnitPoint(x: 0.5, y: 0)))
        .overlay(alignment: .top) {
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(.actionBarBorder)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .fontWeight(.medium)
                .foregroundStyle(.textWeak)
                .accessibilityHidden(true)

            TextField(text: $query,
                      label: {
                          Text("Search", bundle: .module)
                              .foregroundStyle(.textWeak)
                      })
                      .adaptiveTextFieldStyle()
                      .foregroundStyle(.textNorm)
                      .submitLabel(.done)
                      .focused(searchFieldFocus)
                      .asciiCapableKeyboard()
                      .autocorrectionDisabled(true)
                      .onSubmit {
                          searchFieldFocus.wrappedValue = false
                      }
                      .impactHaptic()

            if AppConstants.isMobile {
                Button(action: cleanSearch, label: {
                    Image(systemName: "xmark.circle.fill")
                        .fontWeight(.medium)
                        .foregroundStyle(.textWeak)
                        .animation(.default, value: query.isEmpty)
                        .opacity(query.isEmpty ? 0 : 1)
                        .accessibility(label: Text("Clear search", bundle: .module))
                })
                .adaptiveButtonStyle()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Capsule()
            .fill(.shadow(.inner(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)))
            .shadow(color: .white.opacity(0.2),
                    radius: 1,
                    x: 0,
                    y: 0.5)
            .foregroundStyle(colorScheme == .light ? Color(red: 0.9, green: 0.9, blue: 0.89)
                .opacity(0.7) : Color(red: 0.06,
                                      green: 0.06,
                                      blue: 0.06).opacity(0.8)))
    }
}
