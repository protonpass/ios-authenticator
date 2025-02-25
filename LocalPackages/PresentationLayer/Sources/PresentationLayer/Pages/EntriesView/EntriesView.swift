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
    var mainContainer: some View {
        DynamicContainer(type: searchBarAlignment == .bottom ? .zStack(alignment: .bottom) : .vStack()) {
            actionBar
                .zIndex(1)
            if horizontalSizeClass == .compact {
                list
            } else {
                grid
            }
        }
        .overlay {
            if viewModel.uiModels.isEmpty {
                /// In case there aren't any search results, we can
                /// show the new content unavailable view.
                ContentUnavailableView {
                    Label("No token", systemImage: "shield.slash")
                } description: {
                    Text("No token found. Please consider adding one.")
                } actions: {
                    VStack {
                        Button("Add a new entry") {
                            #if os(iOS)
                            showCreationOptions.toggle()
                            #else
                            router.presentedSheet = .createEditEntry(nil)
                            #endif
                        }
                        .buttonStyle(.bordered)

                        Button("Import tokens") {}
                            .buttonStyle(.bordered)

                        Button(action: {
                            router.presentedSheet = .settings
                        }, label: {
                            Text("Settings")
                        })
                    }
                }
                .foregroundStyle(.textNorm)
            }
        }
    }
}

private extension EntriesView {
    var list: some View {
        List {
            ForEach(viewModel.uiModels) { entry in
                cell(for: entry)
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

    var grid: some View {
        ScrollView {
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())]) {
                ForEach(viewModel.uiModels) { entry in
                    cell(for: entry)
                }
            }
            .padding()
        }
    }

    func cell(for entry: EntryUiModel) -> some View {
        EntryCell(entry: entry,
                  onCopyToken: { viewModel.copyTokenToClipboard(entry) })
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions {
                Button {
                    router.presentedSheet = .createEditEntry(entry.entry)
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

            if !isTextFieldFocused {
                #if os(iOS)
                if isPhone {
                    Button(action: {
                        showCreationOptions.toggle()
                        router.presentedSheet = .createEditEntry(nil)
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
        }
        .animation(.default, value: isTextFieldFocused)
        .foregroundStyle(.textWeak)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color(red: 0.1, green: 0.1, blue: 0.15))
        .cornerRadius(12)
        .background(RoundedRectangle(cornerRadius: 12)
            .inset(by: 0.25)
            .offset(y: 1)
            .stroke(.white.opacity(0.2), lineWidth: 0.5))
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .background(.gradientStart)
        .overlay(alignment: .top) {
            if searchBarAlignment == .bottom {
                // Top border line
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(.gradientEnd)
            }
        }
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
}

#Preview {
    EntriesView()
}
