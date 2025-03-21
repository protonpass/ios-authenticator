//
//
// ExportView.swift
// Proton Authenticator - Created on 20/03/2025.
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

struct ExportView: View {
    @State private var viewModel = ExportViewModel()

    var body: some View {
        ZStack {
            Color.clear
                .mainBackground()
                .edgesIgnoringSafeArea(.all)

            VStack {
                Spacer()
                Text("Export data to Backup File")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
                    .foregroundStyle(.textNorm)
                Spacer()
                Image(systemName: "externaldrive.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.textNorm)
                    .frame(maxWidth: 200)
                    .padding(.horizontal, 45)
                    .padding(.bottom, 20)

                Text("Use this feature to import your data on an another device using Proton Authenticator")
                    .foregroundStyle(.textWeak)
                    .multilineTextAlignment(.center)

                Spacer()

                Button { viewModel.createBackup() } label: {
                    Text("Export to backup file")
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 14)
                .coloredBackgroundButton(.capsule)
                Spacer()
            }
            .padding(.horizontal, 16)
            #if os(iOS)
                .navigationBarTitle("Export")
            #endif
        }
        .fileExporter(isPresented: $viewModel.showingExporter,
                      document: viewModel.backup,
                      contentType: .text,
                      defaultFilename: viewModel.backupTitle,
                      onCompletion: viewModel.parseExport)
        #if os(iOS)
            .edgesIgnoringSafeArea(.all)
            .toolbarBackground(.hidden, for: .navigationBar)
        #endif
    }
}

#Preview {
    ExportView()
}
