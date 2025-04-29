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
                    .foregroundStyle(.textNorm)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .cornerRadius(52)
                    .onTapGesture {
                        withAnimation(.interactiveSpring()) {
                            selection = option
                        }
                    }
            }
        }
        .padding(6)
        .background(movingCapsule)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(.inputBackground)
        .clipShape(.capsule)
        .animation(.default, value: selection)
    }
}

private extension CustomSegmentedControl {
    var movingCapsule: some View {
        HStack(spacing: 0) {
            if let index = data.firstIndex(of: selection) {
                ForEach(0..<index, id: \.self) { _ in
                    Color.clear
                }

                Color.dropdownBackground
                    .clipShape(.capsule)
                    .padding(6)

                ForEach(index..<data.count - 1, id: \.self) { _ in
                    Color.clear
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
