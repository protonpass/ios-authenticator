//
// PassBanner.swift
// Proton Authenticator - Created on 13/02/2025.
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

struct PassBanner: View {
    let onClose: () -> Void
    let onGetPass: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            mainContent
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24)
                    .padding(DesignConstant.padding)
                    .foregroundStyle(.textNorm.opacity(0.7))
            }
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.black.opacity(0.5))
        .background(EllipticalGradient(stops:
            [
                Gradient.Stop(color: Color(red: 1, green: 0.83, blue: 0.5), location: 0.00),
                Gradient.Stop(color: Color(red: 0.96, green: 0.77, blue: 0.57), location: 0.09),
                Gradient.Stop(color: Color(red: 0.92, green: 0.71, blue: 0.64), location: 0.20),
                Gradient.Stop(color: Color(red: 0.88, green: 0.65, blue: 0.68), location: 0.32),
                Gradient.Stop(color: Color(red: 0.83, green: 0.59, blue: 0.75), location: 0.43),
                Gradient.Stop(color: Color(red: 0.77, green: 0.52, blue: 0.8), location: 0.53),
                Gradient.Stop(color: Color(red: 0.71, green: 0.47, blue: 0.85), location: 0.65),
                Gradient.Stop(color: Color(red: 0.63, green: 0.4, blue: 0.9), location: 0.77),
                Gradient.Stop(color: Color(red: 0.54, green: 0.34, blue: 0.95), location: 0.89),
                Gradient.Stop(color: Color(red: 0.44, green: 0.3, blue: 1), location: 1.00)
            ],
            center: UnitPoint(x: 0.04, y: 1)))
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
        .overlay(RoundedRectangle(cornerRadius: 24)
            .inset(by: 0.5)
            .stroke(.white.opacity(0.2), lineWidth: 1))
    }
}

private extension PassBanner {
    var mainContent: some View {
        ZStack {
            HStack {
                Spacer()
                Image("passPreview", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 150, alignment: .trailing)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "Proton Pass")
                    .foregroundStyle(.white)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignConstant.padding)

                GeometryReader { proxy in
                    Text("Store strong, unique passwords to avoid identity theft and breaches.",
                         bundle: .module)
                        .foregroundStyle(.white)
                        .frame(maxWidth: proxy.size.width * 0.75, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, DesignConstant.padding)
                        .padding(.top, DesignConstant.padding / 3)
                }

                Spacer()

                HStack(spacing: DesignConstant.padding / 2) {
                    passItem(imageName: "user", color: .passLogin)
                    passItem(imageName: "alias", color: .passAlias)
                    passItem(imageName: "fileLines", color: .passNote)
                    passItem(imageName: "creditCard", color: .passCreditCard)
                    passItem(imageName: "key", color: .passPassword)
                    Spacer()
                }
                .padding(.horizontal, DesignConstant.padding)

                Spacer()

                HStack(spacing: DesignConstant.padding / 2) {
                    ZStack {
                        Color.white
                        Image("logoPass", bundle: .module)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 22)
                    }
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: "Proton Pass")
                            .fontWeight(.bold)
                        Text("Free", bundle: .module)
                            .font(.callout)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()

                    CapsuleButton(title: "GET",
                                  textColor: .white,
                                  style: .filled,
                                  height: 36,
                                  minWidth: 78,
                                  maxWidth: nil,
                                  weight: .bold,
                                  action: onGetPass)
                }
                .padding(DesignConstant.padding)
                .background(.ultraThinMaterial)
            }
            .padding(.top, DesignConstant.padding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func passItem(imageName: String, color: Color) -> some View {
        ZStack {
            color.opacity(0.16)
            Image(imageName, bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: 20)
                .foregroundStyle(color)
        }
        .frame(width: 36, height: 36)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
