//
// EntriesView.swift
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

import CommonUtilities
import Models
import SwiftUI

public struct EntriesView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel = EntriesViewModel()
    @State private var router = Router()
    @State private var showCreationOptions = false
    @FocusState private var isTextFieldFocused: Bool

    private var isPhone: Bool {
        AppConstants.isPhone
    }

    private var searchBarAlignment: VerticalAlignment {
        isPhone ? .bottom : .top
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            mainContainer
                .background(.backgroundGradient)
                .withSheetDestinations(sheetDestinations: $router.presentedSheet)
                .environment(router)
                .task {
                    await viewModel.setUp()
                    viewModel.refreshTokens()
                }
                .toolbar {
                    ToolbarItem(placement: toolbarItemLeadingPlacement) {
                        Text("Authenticator")
                            .font(.title)
                            .fontWeight(.bold)
                    }
                    ToolbarItem(placement: toolbarItemTrailingPlacement) {
                        Button {
                            router.presentedSheet = .settings
                        } label: {
                            Image(.settingsGear)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding(8)
                                .background(.white.opacity(0.12))
                                .clipShape(Circle())
                                .overlay(Circle()
                                    .stroke(.white, lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
                        }
                    }
                }
                .overlay {
                    overlay
                }
                .adaptiveConfirmationDialog("Create",
                                            isPresented: $showCreationOptions,
                                            actions: {
                                                #if os(iOS)
                                                scanQrCodeButton
                                                #endif
                                                manuallyAddEntryButton
                                            })
                .onChange(of: router.presentedSheet) { _, newValue in
                    // Pause refreshing when a sheet is presented
                    // Only applicable to iPad because sheets on iPad are not full screen
                    guard horizontalSizeClass == .regular else { return }
                    viewModel.toggleCodeRefresh(newValue != nil)
                }
        }
    }
}

private extension EntriesView {
    @ViewBuilder
    var mainContainer: some View {
        if horizontalSizeClass == .compact {
            list
        } else {
            grid
        }
    }

    @ViewBuilder
    var overlay: some View {
        switch viewModel.dataState {
        case .loading:
            ProgressView()
        case let .loaded(entries):
            if entries.isEmpty {
                ContentUnavailableView {
                    Image(.noEntries)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 210, height: 120)
                } description: {
                    VStack {
                        Text("No codes")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .top)
                            .opacity(0.6)
                        Text("Protect your accounts with an extra layer of security.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.textNorm)
                            .frame(width: 305, alignment: .top)
                            .opacity(0.3)
                    }
                } actions: {
                    Button {
                        #if os(iOS)
                        // if isPhone {
                        showCreationOptions.toggle()
                        #else
                        router.presentedSheet = .createEditEntry(nil)

                        #endif
                    } label: {
                        Text("Create new code")
                            .foregroundStyle(.textNorm)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 14)
                    .frame(height: 52, alignment: .center)
                    .buttonBackground(Capsule())
                }
                .foregroundStyle(.textNorm)
            }
        case let .failed(error):
            RetryableErrorView(tintColor: .danger, error: error) {
                viewModel.refreshTokens()
            }
        }
    }
}

private extension EntriesView {
    var list: some View {
        List {
            ForEach(viewModel.entries) { entry in
                cell(for: entry)
            }
            .padding(.horizontal)
            .listRowInsets(EdgeInsets())
        }
        .listStyle(.plain)
        .padding(.top, 3)
        .safeAreaInset(edge: searchBarAlignment == .bottom ? .bottom : .top) {
            if !(viewModel.dataState.data?.isEmpty ?? true) {
                actionBar
            }
        }
        #if os(iOS)
        .listRowSpacing(12)
        #endif
        .background(.backgroundGradient)
        .onTapGesture {
            isTextFieldFocused = false
        }
        .refreshable {
            viewModel.refreshTokens()
        }
    }

    var grid: some View {
        ScrollView {
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())]) {
                ForEach(viewModel.entries) { entry in
                    cell(for: entry)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: searchBarAlignment == .bottom ? .bottom : .top) {
            if !(viewModel.dataState.data?.isEmpty ?? true) {
                actionBar
            }
        }
        .refreshable {
            viewModel.refreshTokens()
        }
    }

    func cell(for entry: EntryUiModel) -> some View {
        EntryCell(entry: entry,
                  onCopyToken: { viewModel.copyTokenToClipboard(entry) })
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions {
                if entry.entry.type == .totp {
                    Button {
                        router.presentedSheet = .createEditEntry(entry)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.yellow)
                }

                Button {
                    viewModel.delete(entry)
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                }
                .tint(.red)
            }
    }

    var actionBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            searchBar
            if !isTextFieldFocused {
                addButton
                    .padding(10)
                    .frame(width: 44, height: 44, alignment: .center)
                    .buttonBackground(Circle())
            }
        }
        .foregroundStyle(.textWeak)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color(red: 0.1, green: 0.1, blue: 0.15))
        .overlay(alignment: .top) {
            if searchBarAlignment == .bottom {
                // Top border line
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(.gradientEnd)
            }
        }
    }

    var searchBar: some View {
        ZStack(alignment: .leading) {
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
                TextField(text: $viewModel.search,
                          label: {
                              if isTextFieldFocused {
                                  Text("Search")
                              }
                          })
                          .focused($isTextFieldFocused)
                          .foregroundStyle(.textNorm)
                          .submitLabel(.done)
                          .onSubmit {
                              isTextFieldFocused = false
                          }
            }
            .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 0)
        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .leading)
        .background(.black)
        .cornerRadius(100)
    }

    @ViewBuilder
    var addButton: some View {
        #if os(iOS)
        if isPhone {
            Button(action: {
                showCreationOptions.toggle()
            }, label: {
                plusIcon
            })
        } else {
            Menu(content: {
                scanQrCodeButton
                manuallyAddEntryButton
            }, label: {
                plusIcon
            })
        }
        #else
        Button(action: {
            router.presentedSheet = .createEditEntry(nil)
        }, label: {
            plusIcon
        })
        #endif
    }

    var plusIcon: some View {
        Image(systemName: "plus")
            .resizable()
            .frame(width: 20, height: 20)
    }

    #if os(iOS)
    var scanQrCodeButton: some View {
        Button(action: {
            router.presentedSheet = .qrCodeScanner
        }, label: {
            Label("Scan", systemImage: "qrcode.viewfinder")
        })
    }
    #endif

    var manuallyAddEntryButton: some View {
        Button(action: {
            router.presentedSheet = .createEditEntry(nil)
        }, label: {
            Label("Enter manually", systemImage: "character.cursor.ibeam")
        })
    }

    var toolbarItemTrailingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .automatic
        #endif
    }

    var toolbarItemLeadingPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarLeading
        #else
        return .automatic
        #endif
    }
}

#Preview {
    EntriesView()
}
