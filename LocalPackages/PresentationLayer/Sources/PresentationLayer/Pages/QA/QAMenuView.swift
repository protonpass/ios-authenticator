//
// QAMenuView.swift
// Proton Authenticator - Created on 15/02/2025.
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

struct QAMenuView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = QAMenuViewModel()

    var body: some View {
        NavigationStack {
            List {
                onboardingSection
                passBannerSection
                scannerSection
                actionsSection
                keychainContent
                dataContent
                installationDateSection
            }
            .showSpinner(viewModel.isLoading)
            .navigationTitle(Text(verbatim: "QA menu"))
            .toolbar {
                ToolbarItem(placement: toolbarItemPlacement) {
                    Button(action: dismiss.callAsFunction) {
                        Text(verbatim: "Close")
                    }
                }
            }
        }
    }

    private var toolbarItemPlacement: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarLeading
        #else
        return .navigation
        #endif
    }
}

private extension QAMenuView {
    var onboardingSection: some View {
        Section(content: {
            Toggle(isOn: $viewModel.onboarded, label: { Text(verbatim: "Onboarded") })
        }, header: {
            Text(verbatim: "Onboarding")
        })
    }

    var passBannerSection: some View {
        Section(content: {
            Toggle(isOn: $viewModel.displayPassBanner,
                   label: { Text(verbatim: "Display Pass Banner") })
        }, header: {
            Text(verbatim: "Pass Banner")
        })
    }

    var scannerSection: some View {
        Section(content: {
            Toggle(isOn: $viewModel.unsupportedScanning,
                   label: { Text(verbatim: "Scanner not available") })
        }, header: {
            Text(verbatim: "Scanner")
        }, footer: {
            Text(verbatim: "Simulate unavailable scanner")
        })
    }

    var actionsSection: some View {
        Section(content: {
            Button {
                viewModel.deleteAllKeychainData()
            } label: {
                Text(verbatim: "Remove all data stored in keychain")
            }

            Button {
                viewModel.deleteAllKeychainData(synchronized: true)
            } label: {
                Text(verbatim: "Remove all synchronized data stored in keychain")
            }

            Button {
                viewModel.deleteAllKeychainData(synchronized: false)
            } label: {
                Text(verbatim: "Remove all non synchronized data stored in keychain")
            }

            Button {
                viewModel.deleteAllLogs()
            } label: {
                Text(verbatim: "Remove all local logs")
            }
        }, header: {
            Text(verbatim: "Actions")
        })
    }

    var keychainContent: some View {
        Section(content: {
            Button {
                viewModel.loadKeychainContent()
            } label: {
                Text(verbatim: "Refresh content of keychain")
            }

            NavigationLink(destination: {
                List {
                    ForEach(viewModel.keychainContent) { element in
                        NavigationLink(destination: {
                            List {
                                ForEach(element.content.keys.sorted(), id: \.self) { key in
                                    VStack(alignment: .leading) {
                                        Text(verbatim: "Key: \(key)")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text(verbatim: "Content: \(String(describing: element.content[key]))")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        if let data = element.content[key] as? Data {
                                            Text(verbatim: "Hexa of content: \(data.hexString)")
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        Text(verbatim: "")
                                    }
                                }
                            }
                            .navigationTitle(Text(verbatim: element.key))
                        }, label: {
                            Text(verbatim: element.key)
                        })
                    }
                }
                .navigationTitle(Text(verbatim: "\(viewModel.keychainContent.count) keys"))
            }, label: {
                Text(verbatim: "View all \(viewModel.keychainContent.count) keys")
            })
        }, header: {
            Text(verbatim: "Keychain Content")
        })
    }

    var dataContent: some View {
        Section(content: {
            Button {
                viewModel.loadEntryContent()
            } label: {
                Text(verbatim: "Refresh display of data")
            }

            if let content = viewModel.entriesContent {
                VStack(alignment: .leading, spacing: 15) {
                    Text(verbatim: "Total amount of entries stored on the device: " +
                        "\(content.numberOfDecryptedEntries + content.numberOfUnDecryptableEntries)")
                    Text(verbatim: "Total amount of decryptable entries: \(content.numberOfDecryptedEntries)")
                    Text(verbatim: "Total amount of nonDecryptable entries: \(content.numberOfUnDecryptableEntries)")
                }
            }
        }, header: {
            Text(verbatim: "Entry Content")
        })
    }

    var installationDateSection: some View {
        Section(content: {
            DatePicker(selection: $viewModel.installationDate,
                       in: ...Date.now,
                       displayedComponents: .date) {
                Text(verbatim: "Installation date")
            }
        }, header: {
            Text(verbatim: "Installation date")
        })
        .onChange(of: viewModel.installationDate) { _, newDate in
            viewModel.updateInstallationTimestamp(newDate)
        }
    }
}
