//
// ReachabilityManager.swift
// Proton Authenticator - Created on 10/07/2025.
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

@preconcurrency import Combine
import CommonUtilities
import Foundation
import Network

public enum NerworkType: Sendable {
    case wifi
    case cellular
    case loopBack
    case wired
    case other
}

public protocol ReachabilityServicing: Sendable {
    var reachabilityInfos: PassthroughSubject<NWPath, Never> { get }
    var isNetworkAvailable: CurrentValueSubject<Bool, Never> { get }
    var typeOfCurrentConnection: PassthroughSubject<NerworkType, Never> { get }
    var hasInternetAccess: CurrentValueSubject<Bool, Never> { get }
}

public final class ReachabilityManager: ReachabilityServicing {
    public let reachabilityInfos: PassthroughSubject<NWPath, Never> = .init()
    public let isNetworkAvailable: CurrentValueSubject<Bool, Never> = .init(false)
    public let typeOfCurrentConnection: PassthroughSubject<NerworkType, Never> = .init()
    public let hasInternetAccess: CurrentValueSubject<Bool, Never> = .init(false)

    private let monitor: NWPathMonitor
    private let backgroundQueue = DispatchQueue.global(qos: .background)
    private let currentConnectivityTask: any MutexProtected<Task<Void, Never>?> = SafeMutex.create(nil)
    private let connectivityTestURL: URL
    private let urlSession: URLSession

    public init(monitorInterfaceType: NWInterface.InterfaceType? = nil,
                // swiftlint:disable:next force_unwrapping
                connectivityTestURL: URL = URL(string: "https://www.apple.com/library/test/success.html")!,
                urlSession: URLSession = {
                    let config = URLSessionConfiguration.ephemeral
                    config.timeoutIntervalForRequest = 1
                    config.timeoutIntervalForResource = 1
                    return URLSession(configuration: config)
                }()) {
        monitor = if let monitorInterfaceType {
            NWPathMonitor(requiredInterfaceType: monitorInterfaceType)
        } else {
            NWPathMonitor()
        }

        self.connectivityTestURL = connectivityTestURL
        self.urlSession = urlSession
        setUp()
    }

    deinit {
        monitor.cancel()
    }
}

private extension ReachabilityManager {
    func setUp() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            reachabilityInfos.send(path)
            switch path.status {
            case .satisfied:
                isNetworkAvailable.send(true)
                checkActualConnectivity()
            case .requiresConnection, .unsatisfied:
                resetNoConnexion()
            @unknown default:
                resetNoConnexion()
            }
            if path.usesInterfaceType(.wifi) {
                typeOfCurrentConnection.send(.wifi)
            } else if path.usesInterfaceType(.cellular) {
                typeOfCurrentConnection.send(.cellular)
            } else if path.usesInterfaceType(.loopback) {
                typeOfCurrentConnection.send(.loopBack)
            } else if path.usesInterfaceType(.wiredEthernet) {
                typeOfCurrentConnection.send(.wired)
            } else if path.usesInterfaceType(.other) {
                typeOfCurrentConnection.send(.other)
                // This is called when connected to aVPN we need to check is we actually have a connection to
                // internet
                checkActualConnectivity()
            }
        }

        monitor.start(queue: backgroundQueue)
    }

    func resetNoConnexion() {
        isNetworkAvailable.send(false)
        hasInternetAccess.send(false)
        currentConnectivityTask.modify {
            $0?.cancel()
        }
    }

    func checkActualConnectivity() {
        // Cancel previous check if it exists
        currentConnectivityTask.modify {
            $0?.cancel()
        }

        currentConnectivityTask.modify {
            $0 = Task { [weak self] in
                guard let self else { return }

                do {
                    // Use HEAD method to only check headers
                    var request = URLRequest(url: connectivityTestURL)
                    request.httpMethod = "HEAD"

                    let (_, response) = try await urlSession.data(for: request)
                    let success = (response as? HTTPURLResponse)?.statusCode == 200

                    // Only update if task wasn't cancelled
                    if !Task.isCancelled {
                        hasInternetAccess.send(success)
                    }
                } catch {
                    // Ignore cancellation errors
                    if !(error is CancellationError), !Task.isCancelled {
                        hasInternetAccess.send(false)
                    }
                }
            }
        }
    }
}
