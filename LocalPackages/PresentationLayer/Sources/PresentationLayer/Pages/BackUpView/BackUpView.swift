//
//
// BackUpView.swift
// Proton Authenticator - Created on 18/07/2025.
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

import Macro
import Models
import SwiftUI

struct BackUpView: View {
    @State private var viewModel = BackUpViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack {
            section {
                SettingRow(title: .localized("Automatic Backup", .module),
                           trailingMode: .toggle(isOn: viewModel.backupActivated,
                                                 onToggle: viewModel.toggleBackICloudUp))
            }
            .frame(maxHeight: 75)

            if viewModel.backupActivated, !viewModel.backups.isEmpty {
                section("BACKUPS") {
                    ForEach(viewModel.backups) { backup in
                        Button { viewModel.load(backup: backup) } label: {
                            row(title: .localized("Backup from \(backup.displayedDate)", .module))
                        }
                        .buttonStyle(.plain)

                        if backup != viewModel.backups.last {
                            Divider()
                        }
                    }
                }
                VStack {
                    Text("Only the last 5 backups are kept.", bundle: .module)
                    if let displayedDate = viewModel.backups.first?.displayedDate {
                        Text("Last backup: \(displayedDate)", bundle: .module)
                    }
                }
                .font(Font.custom("SF Pro Text", size: 13))
                .foregroundStyle(.textWeak)
                .padding(.top, 32)
            }
            Spacer()
        }
        .frame(maxHeight: .infinity)
        .animation(.default, value: viewModel.backupActivated)
        .task {
            await viewModel.loadData()
        }
        .showSpinner(viewModel.loading)
        .padding(.bottom, 10)
        .scrollContentBackground(.hidden)
        .errorMessageAlert($viewModel.errorMessage)
        .sheetAlertService()
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
            .navigationTitle(Text("Backups", bundle: .module))
            .fullScreenMainBackground()
    }

    func section(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: DesignConstant.padding) {
            if let title {
                Text(title, bundle: .module)
                    .dynamicFont(size: 13, textStyle: .footnote)
                    .foregroundStyle(.textWeak)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignConstant.padding)
            }

            LazyVStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(isDarkMode ? .white.opacity(0.08) : .white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .inset(by: 0.5)
                .stroke(settingsBorder, lineWidth: 1))
        }
        .plainListRow()
        .padding(.horizontal, DesignConstant.padding)
        .padding(.top, DesignConstant.padding * 2)
    }

    func row(title: TextContent) -> some View {
        HStack(spacing: 0) {
            Text(title) // ignore:missing_bundle
                .foregroundStyle(.textNorm)
                .dynamicFont(size: 17, textStyle: .body)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .foregroundStyle(.textNorm)
        }
        .padding(DesignConstant.padding)
        .contentShape(.rect)
    }

    private func activateStatus(_ active: Bool) -> String {
        active ? #localized("Enabled", bundle: .module) : #localized("Disabled", bundle: .module)
    }

    private var isDarkMode: Bool {
        colorScheme == .dark
    }

    private var settingsBorder: Color {
        (isDarkMode ? Color.white : .black).opacity(0.12)
    }
}

#Preview {
    BackUpView()
}
