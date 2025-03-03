//
//
// ScannerView.swift
// Proton Authenticator - Created on 28/02/2025.
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

#if os(iOS)

import DocScanner
import PhotosUI
import SwiftUI

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = ScannerViewModel()
    @State private var showPhotosPicker = false

    var body: some View {
        DataScanner(with: .barcode,
                    startScanning: $viewModel.scanning,
                    automaticDismiss: false,
                    regionOfInterest: $viewModel.regionOfInterest) { results in
            viewModel.processPayload(results: results)
        }
        .onChange(of: viewModel.shouldDismiss) {
            dismiss()
        }
        .alert("Error occurred while parsing the Qr code",
               isPresented: $viewModel.displayErrorAlert,
               actions: {
                   Button { viewModel.clean() } label: {
                       Text("OK")
                   }
               },
               message: {
                   if let message = viewModel.creationError?.localizedDescription {
                       Text(message)
                   }
               })
        .photosPicker(isPresented: $showPhotosPicker,
                      selection: $viewModel.imageSelection,
                      matching: .images,
                      photoLibrary: .shared())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(regionOfInterestOverlay)
    }

    @ViewBuilder
    var regionOfInterestOverlay: some View {
        RestrictedScanningArea(regionOfInterest: $viewModel.regionOfInterest,
                               photoLibraryEntry: {
                                   showPhotosPicker.toggle()
                               })
    }
}

#Preview {
    ScannerView()
}
#endif
