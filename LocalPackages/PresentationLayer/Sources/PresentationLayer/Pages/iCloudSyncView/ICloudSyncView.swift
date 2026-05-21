//
//
// ICloudSyncView.swift
// Proton Authenticator - Created on 20/05/2026.
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
//

import CommonUtilities
import Macro
import Models
import SwiftUI

struct ICloudSyncView: View {
    @State private var viewModel = ICloudSyncViewModel()

    var body: some View {
        mainContent
            .navigationTitle(Text("iCloud Sync", bundle: .module))
            .fullScreenMainBackground()
    }

    var mainContent: some View {
        List {
            setupSection
        }
        .scrollBounceBehavior(.basedOnSize)
        .listStyle(.insetGrouped)
        .frame(maxHeight: .infinity)
    }

    var setupSection: some View {
        SettingsSectionContainer(title: "ICLOUD SETTINGS") {
            // swiftlint:disable:next line_length
            Label("Due to reliability issues with Apple's iCloud, we recommend using Proton sync and/or backup system instead.",
                  systemImage: "exclamationmark.triangle")

            SettingRow(title: .localized("Sync via iCloud", .module),
                       trailingMode: .toggle(isOn: viewModel.iCloudSync,
                                             onToggle: viewModel.toggleICloudSyncBackup))
                .toggleAccessibilityLabel(#localized("Sync with iCloud", bundle: .module),
                                          activateStatus(viewModel.iCloudSync))

            SettingDivider()
        }
    }

    func activateStatus(_ active: Bool) -> String {
        active ? #localized("Enabled", bundle: .module) : #localized("Disabled", bundle: .module)
    }
}

#Preview {
    ICloudSyncView()
}
