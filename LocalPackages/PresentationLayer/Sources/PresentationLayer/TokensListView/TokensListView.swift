//
//
// TokensListView.swift
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
//

import SwiftUI

public struct TokensListView: View {
    @State private var viewModel = TokensListViewModel()
    @State private var router: Router = .init()
    @FocusState private var isTextFieldFocused: Bool

    public init() {}

    public var body: some View {
        NavigationStack {
            mainContainer
                .withSheetDestinations(sheetDestinations: $router.presentedSheet)
                .environment(router)
        }
    }
}

private extension TokensListView {
    var mainContainer: some View {
        ZStack(alignment: .bottom) {
            // TODO: grid for ipad and mac
            list
            actionBar
        }
        .overlay {
            if viewModel.tokens.isEmpty {
                /// In case there aren't any search results, we can
                /// show the new content unavailable view.
                ContentUnavailableView {
                    Label("No token", systemImage: "shield.slash")
                } description: {
                    Text("No token found. Please consider adding one.")
                } actions: {
                    VStack {
                        Button("Add a new token") {
                            addToken()
                        }
                        .buttonStyle(.bordered)

                        Button("Import tokens") {}
                            .buttonStyle(.bordered)
                    }
                }
                .foregroundStyle(.textNorm)
                .background(.backgroundGradient)
            }
        }
    }
}

private extension TokensListView {
    var list: some View {
        List {
            ForEach(viewModel.tokens, id: \.self) { token in
                TokenListCell(token: token)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .swipeActions {
                        Button {
                            router.presentedSheet = .createEditToken(token)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.yellow)

                        Button {} label: {
                            Label("Delete", systemImage: "trash.fill")
                        }
                        .tint(.red)
                    }
            }
            .padding(.horizontal)
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
        #if os(iOS)
            .listRowSpacing(12)
        #endif
            .background(.backgroundGradient)
            .animation(.default, value: isTextFieldFocused)
            .onTapGesture {
                isTextFieldFocused = false
            }
    }

    var actionBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !isTextFieldFocused {
                Button {
                    router.presentedSheet = .settings
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
            }

            ZStack(alignment: .center) {
                // Show the placeholder only when text is empty.
                if viewModel.search.isEmpty, !isTextFieldFocused {
                    HStack(spacing: 4) {
                        Label("Search", systemImage: "magnifyingglass")
                            .foregroundStyle(.textWeak)
                    }
                    .padding(.leading, 8)
                }

                HStack {
                    if isTextFieldFocused {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.textWeak)
                    }
                    // The actual text field.
                    TextField("", text: $viewModel.search)
                        .focused($isTextFieldFocused)
                        .foregroundStyle(.textNorm)
                        .onSubmit {
                            isTextFieldFocused = false
                        }
                }
                .padding(.leading, 8)
            }
            .animation(.default, value: isTextFieldFocused)

            if !isTextFieldFocused {
                Button {
                    addToken()
                } label: {
                    Image(systemName: "plus")
                        .resizable()
                        .frame(width: 20, height: 20)
                }
            }
        }
        .foregroundStyle(.textWeak)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.5))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .inset(by: 0.25)
            .stroke(.white.opacity(0.2), lineWidth: 0.5))
        .padding(.horizontal, 22)
        .padding(.bottom, 15)
    }

    func addToken() {
        router.presentedSheet = {
            #if os(iOS)
            return .barcodeScanner
            #else
            return .createEditToken(nil)
            #endif
        }()
    }
}

#Preview {
    TokensListView()
}
