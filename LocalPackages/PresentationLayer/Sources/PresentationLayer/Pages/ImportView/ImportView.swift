//
//
// ImportView.swift
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
//
// import Models
// import SwiftUI
//
// struct ImportView: View {
//    @Environment(\.colorScheme) private var colorScheme
//    @State private var viewModel = ImportViewModel()
//    @State private var passwordProtectedFile: Bool = false
//    @State private var provenance: ImportOption?
//
//    var body: some View {
//        ZStack {
//            Color.clear
//                .mainBackground()
//                .edgesIgnoringSafeArea(.all)
//
////            VStack {
////                ForEach(ImportOption.allCases) { provenance in
////                    Button {
////                        viewModel.importEntries(provenance)
////                    } label: {
////                        HStack {
////                            Image(.logoCalendar)
////                            Text("Import from \(provenance.title)")
////                                .foregroundStyle(.white)
////                                .fontWeight(.semibold)
////                                .frame(maxWidth: .infinity, alignment: .leading)
////                            Spacer()
////                        }
////                    }
////                    .padding(.horizontal, 30)
////                    .padding(.vertical, 14)
////                    .background((colorScheme == .light ? Color.black : .white).opacity(0.4))
////                    .clipShape(RoundedRectangle(cornerRadius: 15))
////                }
////            }
////            .padding(.horizontal, 16)
////            .navigationBarTitle("Import")
//        }
////        .sheet(isPresented: $viewModel.showPasswordSheet) {
////            VStack {
////                Text("Your import file is password protected. Please enter the password to proceed.")
////                TextField("Password", text: $viewModel.password)
////
////                Button {
////                    viewModel.encryptedImport()
////                } label: {
////                    HStack {
////                        Image(.logoCalendar)
////                        Text("Import")
////                            .foregroundStyle(.white)
////                            .fontWeight(.semibold)
////                            .frame(maxWidth: .infinity, alignment: .leading)
////                        Spacer()
////                    }
////                }
////                .padding(.horizontal, 30)
////                .padding(.vertical, 14)
////                .background((colorScheme == .light ? Color.black : .white).opacity(0.4))
////                .clipShape(RoundedRectangle(cornerRadius: 15))
////                .disabled(viewModel.password.isEmpty)
////            }
////        }
////        .fileImporter(isPresented: $viewModel.showImporter.mappedToBool(),
////                      allowedContentTypes: viewModel.showImporter?.autorizedFileExtensions ?? [],
////                      allowsMultipleSelection: false,
////                      onCompletion: viewModel.processImportedFile)
////        .edgesIgnoringSafeArea(.all)
////        .toolbarBackground(.hidden, for: .navigationBar)
//    }
// }
//
// #Preview {
//    ImportView()
// }
