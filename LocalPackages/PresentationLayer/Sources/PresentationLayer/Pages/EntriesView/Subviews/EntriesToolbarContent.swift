//
// EntriesToolbarContent.swift
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
import Models
import SwiftUI

struct EntriesToolbarContent: ToolbarContent {
    let sortOption: SortOption
    let setSortOption: (SortOption) -> Void
    @Binding var presentedSheet: SheetDestination?
    let searchBarAlignment: VerticalAlignment
    let noEntries: Bool
    let handleAddNewCode: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: titlePlacement) {
            Text(verbatim: "Proton Authenticator")
                .foregroundStyle(.textNorm)
                .dynamicFont(size: 28, textStyle: .title1, weight: .bold)
                .minimumScaleFactor(0.75)
        }

        #if os(iOS)
        ToolbarItem(placement: .topBarTrailing) {
            Menu(content: {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button(action: {
                        setSortOption(option)
                    }, label: {
                        Toggle(isOn: .constant(option == sortOption)) {
                            Text(option.description, bundle: .module)
                        }
                    })

                    switch option {
                    case .creationDateDesc, .issuerDesc, .manual:
                        Divider()

                    default:
                        EmptyView()
                    }
                }
            }, label: {
                Group {
                    if #available(iOS 26, macOS 26, *) {
                        Image(systemName: "line.3.horizontal.decrease")
                    } else {
                        Image(.sortButton)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                    }
                }
                .impactHaptic()
                .accessibilityLabel("Sort options")
            })
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                presentedSheet = .settings
            } label: {
                if #available(iOS 26, macOS 26, *) {
                    Image(systemName: "gearshape.fill")
                } else {
                    Image(.settingsGear)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                }
            }
            .adaptiveButtonStyle()
            .impactHaptic()
            .accessibilityLabel("Settings")
        }
        #endif

        if #available(iOS 26, macOS 26, *),
           !noEntries,
           AppConstants.adjustableSearchBarPosition {
            if searchBarAlignment == .bottom {
                DefaultToolbarItem(kind: .search, placement: .bottomBar)
                ToolbarItem(placement: .bottomBar) {
                    Button(action: handleAddNewCode) {
                        Image(systemName: "plus")
                            .contentShape(.rect)
                    }
                    .contentShape(.rect)
                    .impactHaptic()
                    .accessibilityLabel("Create new code")
                    .buttonStyle(.glassProminent)
                }
            } else {
                DefaultToolbarItem(kind: .search)
            }
        }
    }

    private var titlePlacement: ToolbarItemPlacement {
        if #available(iOS 26, macOS 26, *) {
            .principal
        } else {
            ProcessInfo.processInfo.isiOSAppOnMac ? .topBarLeading : .principal
        }
    }
}
