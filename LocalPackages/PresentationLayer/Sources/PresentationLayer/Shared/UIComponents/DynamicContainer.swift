//
// DynamicContainer.swift
// Proton Authenticator - Created on 18/02/2025.
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

struct DynamicContainer<Content: View>: View {
    let type: ViewType
    @ViewBuilder let content: () -> Content

    enum ViewType {
        case vStack(alignment: HorizontalAlignment? = nil, spacing: CGFloat? = nil)
        case hStack(alignment: VerticalAlignment? = nil, spacing: CGFloat? = nil)
        case zStack(alignment: Alignment? = nil)
    }

    var body: some View {
        switch type {
        case let .vStack(alignment, spacing):
            VStack(alignment: alignment ?? .center, spacing: spacing, content: content)
        case let .hStack(alignment, spacing):
            HStack(alignment: alignment ?? .center, spacing: spacing, content: content)
        case let .zStack(alignment):
            ZStack(alignment: alignment ?? .center, content: content)
        }
    }
}
