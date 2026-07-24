//
// Icon.swift
// Proton Authenticator - Created on 24/07/2026.
// Copyright (c) 2026 Proton Technologies AG
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

enum Icon: Hashable {
    case system(String) // SF Symbol, e.g. "paperplane"
    case resource(ImageResource) // asset-catalog image or symbol image set

    var image: Image {
        switch self {
        case let .system(name): Image(systemName: name)
        case let .resource(res): Image(res)
        }
    }
}
