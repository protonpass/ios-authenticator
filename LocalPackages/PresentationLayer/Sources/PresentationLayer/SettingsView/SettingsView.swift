//
//
// SettingsView.swift
// Proton Authenticator - Created on 10/02/2025.
// Copyright (c) 2025 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Pass is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Pass is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SettingsViewModel()
    @State private var router = Router()

    var body: some View {
        NavigationStack(path: $router.path) {
            List {
                createSection(title: "SECURITY") {
                    VStack(alignment: .leading, spacing: 0) {
                        Button {} label: {
                            Text("App")
                                .foregroundStyle(.textNorm)
                                .padding(16)
                        }
                    }
                }

                createSection(title: "APPEARANCE") {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingNavigationRowView(title: "Theme")

                        Rectangle()
                            .foregroundStyle(.clear)
                            .frame(maxWidth: .infinity, minHeight: 1, maxHeight: 1)
                            .background(.white.opacity(0.12))

                        SettingNavigationRowView(title: "List style")
                    }
                }

                createSection(title: "MANAGE YOUR DATA") {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingNavigationRowView(title: "Import")

                        Rectangle()
                            .foregroundStyle(.clear)
                            .frame(maxWidth: .infinity, minHeight: 1, maxHeight: 1)
                            .background(.white.opacity(0.12))

                        SettingNavigationRowView(title: "Export")
                    }
                }

                createSection(title: "SUPPORT") {
                    VStack(alignment: .leading, spacing: 0) {
                        SettingNavigationRowView(title: "How to use Proton Authenticator")

                        Rectangle()
                            .foregroundStyle(.clear)
                            .frame(maxWidth: .infinity, minHeight: 1, maxHeight: 1)
                            .background(.white.opacity(0.12))

                        SettingNavigationRowView(title: "Feedback")
                    }
                }

                createSection(title: "DISCOVER PROTON") {}
            }
            .listStyle(.plain)
            .routingProvided
            .navigationTitle("Settings")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .background(.backgroundGradient)
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Close")
                                .foregroundStyle(.textWeak)
                        }
                    }
                    #elseif os(macOS)
                    ToolbarItem(placement: .navigation) {
                        Button {
                            dismiss()
                        } label: {
                            Text("Close")
                                .foregroundStyle(.textWeak)
                        }
                    }
                    #endif
                }
            #if os(iOS)
                .toolbarColorScheme(.dark, for: .navigationBar, .tabBar)
                .toolbarBackground(.gradientStart, for: .navigationBar, .tabBar)
                .toolbarBackground(.visible, for: .navigationBar, .tabBar)
            #endif
                .accentColor(.gradientStart)
        }
    }

    func createSection(title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        Section {
            content()
                .padding(.horizontal, 0)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(.white.opacity(0.08))
                .cornerRadius(24)
                .overlay(RoundedRectangle(cornerRadius: 24)
                    .inset(by: 0.5)
                    .stroke(.white.opacity(0.12), lineWidth: 1))
        } header: {
            Text(title)
                .font(Font.custom("SF Pro", size: 13))
                .padding(.leading, 16)
                .padding(.bottom, 16)
                .foregroundStyle(.textWeak)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .padding(.horizontal, 16)
        .listRowInsets(EdgeInsets())
    }
}

#Preview {
    SettingsView()
}

private struct SettingNavigationRowView: View {
    let title: LocalizedStringKey

    var body: some View {
        HStack {
            Text(title)
                .font(.system(.body, design: .rounded))
            Spacer()
            Image(systemName: "chevron.right")
        }
        .foregroundStyle(.textNorm)
        .padding(16)
    }
}
