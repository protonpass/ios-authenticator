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

// import SwiftUI
//
// struct ScannerView: View {
//    @State private var viewModel = ScannerViewModel()
//
//    var body: some View {
//        Text("Add some view here")
//    }
// }
//
// #Preview {
//        ScannerView()
// }

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

public struct RestrictedScanningAreaConfig {
    let overlayColor: Color
    let sizeOfArea: CGSize
    let border: Bool
    let borderCornerRadius: CGFloat
    let borderColor: Color
    let borderColorWidth: CGFloat

    public init(overlayColor: Color = .black.opacity(0.4),
                sizeOfArea: CGSize = CGSize(width: 330, height: 330),
                border: Bool = true,
                borderCornerRadius: CGFloat = 5,
                borderColor: Color = Color(red: 1, green: 0.85, blue: 0.65),
                borderColorWidth: CGFloat = 2) {
        self.overlayColor = overlayColor
        self.sizeOfArea = sizeOfArea
        self.border = border
        self.borderCornerRadius = borderCornerRadius
        self.borderColor = borderColor
        self.borderColorWidth = borderColorWidth
    }

    public static var `default`: RestrictedScanningAreaConfig {
        RestrictedScanningAreaConfig()
    }
}

public struct RestrictedScanningArea: View {
    @Environment(\.dismiss) private var dismiss

    @Binding private var regionOfInterest: CGRect?
    private let configuration: RestrictedScanningAreaConfig
    private let manualEntry: () -> Void
    private let photoLibraryEntry: () -> Void

    public init(configuration: RestrictedScanningAreaConfig = .default,
                regionOfInterest: Binding<CGRect?> = Binding.constant(nil),
                manualEntry: @escaping () -> Void = {},
                photoLibraryEntry: @escaping () -> Void = {}) {
        self.configuration = configuration
        self.manualEntry = manualEntry
        self.photoLibraryEntry = photoLibraryEntry
        _regionOfInterest = regionOfInterest
    }

    public var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(configuration.overlayColor)

            VStack {
                Spacer()
                Rectangle()
                    .frame(width: configuration.sizeOfArea.width, height: configuration.sizeOfArea.height)
                    .blendMode(.destinationOut)
                    .overlay(CornerBorder(cornerRadius: 5, cornerLength: 80)
                        .stroke(configuration.borderColor, lineWidth: 4))
                    .background(GeometryReader { geometry -> Color in
                        DispatchQueue.main.async {
                            regionOfInterest = geometry.frame(in: .global)
                        }
                        return Color.clear
                    })

                Text("Point your camera at the Qr code")
                    .font(.headline)
                    .fontWeight(.medium)
                    .padding(.top, 20)

                Spacer()
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(.white)
                    }

                    Spacer()
                    Button {} label: {
                        Text("Enter manually")
                            .foregroundStyle(.white)
                            .padding(.horizontal, 36)
                            .padding(.vertical, 10)
                            .background(Color(red: 0.1, green: 0.1, blue: 0.15))
                            .cornerRadius(43)
                    }
                    Spacer()

                    Button { photoLibraryEntry() } label: {
                        Image(systemName: "rectangle.stack")
                            .resizable()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 32)
                Spacer()
            }
        }
        .compositingGroup()
    }

    @ViewBuilder
    var border: some View {
        if configuration.border {
            RoundedRectangle(cornerRadius: configuration.borderCornerRadius)
                .stroke(configuration.borderColor, lineWidth: configuration.borderColorWidth)
        }
    }
}

struct CornerBorder: Shape {
    var cornerRadius: CGFloat
    var cornerLength: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Top-left corner
        path.move(to: CGPoint(x: 0, y: cornerRadius + cornerLength))
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))
        path.addArc(center: CGPoint(x: cornerRadius, y: cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(180),
                    endAngle: .degrees(270),
                    clockwise: false)
        path.addLine(to: CGPoint(x: cornerLength + cornerRadius, y: 0))

        // Top-right corner
        path.move(to: CGPoint(x: rect.maxX - cornerLength - cornerRadius, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: 0))
        path.addArc(center: CGPoint(x: rect.maxX - cornerRadius, y: cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(270),
                    endAngle: .degrees(0),
                    clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: cornerRadius + cornerLength))

        // Bottom-right corner
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius - cornerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addArc(center: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(0),
                    endAngle: .degrees(90),
                    clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX - cornerLength - cornerRadius, y: rect.maxY))

        // Bottom-left corner
        path.move(to: CGPoint(x: cornerLength + cornerRadius, y: rect.maxY))
        path.addLine(to: CGPoint(x: cornerRadius, y: rect.maxY))
        path.addArc(center: CGPoint(x: cornerRadius, y: rect.maxY - cornerRadius),
                    radius: cornerRadius,
                    startAngle: .degrees(90),
                    endAngle: .degrees(180),
                    clockwise: false)
        path.addLine(to: CGPoint(x: 0, y: rect.maxY - cornerRadius - cornerLength))

        return path
    }
}

public extension Binding where Value == Bool {
    @MainActor
    init(bindingOptional: Binding<(some Any)?>) {
        self.init(get: {
                      bindingOptional.wrappedValue != nil
                  },
                  set: { newValue in
                      guard newValue == false else { return }
                      bindingOptional.wrappedValue = nil
                  })
    }
}

public extension Binding {
    @MainActor
    func mappedToBool<Wrapped>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(bindingOptional: self)
    }
}
