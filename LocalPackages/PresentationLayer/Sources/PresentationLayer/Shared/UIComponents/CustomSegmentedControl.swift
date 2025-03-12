//
// CustomSegmentedControl.swift
// Proton Authenticator - Created on 12/03/2025.
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

import SwiftUI

typealias CustomSegmentedControlData = Equatable & Hashable & Identifiable & RawRepresentable

struct CustomSegmentedControl<T: CustomSegmentedControlData>: View {
    let data: [T]
    @Binding var selection: T

    var body: some View {
        HStack(spacing: 0) {
            ForEach(data) { option in
                Text(verbatim: "\(option.rawValue)".uppercased())
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(option == selection ? .white.opacity(0.12) : .clear)
                    .cornerRadius(52)
                    .onTapGesture {
                        withAnimation(.interactiveSpring()) {
                            selection = option
                        }
                    }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(.black.opacity(0.5))
        .cornerRadius(100)
    }
}
