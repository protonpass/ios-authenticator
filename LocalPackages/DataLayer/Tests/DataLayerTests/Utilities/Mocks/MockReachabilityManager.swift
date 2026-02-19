//
// MockReachabilityManager.swift
// Proton Authenticator - Created on 19/02/2026.
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

@preconcurrency import Combine
@testable import DataLayer
import Foundation
import Network

final class MockReachabilityManager: ReachabilityServicing {
    let reachabilityInfos = PassthroughSubject<NWPath, Never>()
    let isNetworkAvailable = CurrentValueSubject<Bool, Never>(true)
    let typeOfCurrentConnection = PassthroughSubject<NerworkType, Never>()
    let hasInternetAccess = CurrentValueSubject<Bool, Never>(true)
}
