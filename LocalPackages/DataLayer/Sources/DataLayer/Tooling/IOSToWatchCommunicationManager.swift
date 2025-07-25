//
// IOSToWatchCommunicationManager.swift
// Proton Authenticator - Created on 25/07/2025.
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

import Foundation
import Models
import UIKit
import WatchConnectivity

public final class IOSToWatchCommunicationManager: NSObject, WCSessionDelegate, @unchecked Sendable {
    private let session: WCSession
    private let entryDataService: any EntryDataServiceProtocol
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(session: WCSession = .default,
                entryDataService: any EntryDataServiceProtocol) {
        self.session = session
        decoder = JSONDecoder()
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        self.entryDataService = entryDataService
        super.init()
        self.session.delegate = self
        self.session.activate()
        print("woot session activated \(self.session.activationState == .activated), isPaired: \(self.session.isPaired), isWatchAppInstalled: \(self.session.isWatchAppInstalled)")
    }

    public func checkIfActive() {
        if session.activationState != .activated {
            session.activate()
        }
        print("woot retry session activated \(session.activationState == .activated), isPaired: \(session.isPaired), isWatchAppInstalled: \(session.isWatchAppInstalled)")
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {}

    public func session(_ session: WCSession,
                        activationDidCompleteWith activationState: WCSessionActivationState,
                        error: (any Error)?) {}

    public func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        do {
            let message = try decoder.decode(WatchIOSMessageType.self, from: messageData)
            try parseMessage(message: message)
        } catch {
            print(error)
        }
    }
}

private extension IOSToWatchCommunicationManager {
    func parseMessage(message: WatchIOSMessageType) throws {
        print("woot message received: \(message)")
        Task { [weak self] in
            guard let self else { return }
            do {
                switch message {
                case .syncData:
                    let entries = await entryDataService.extractingOrderedEntry()
                    try sendMessage(message: .dataContent(entries))
                case let .code(newCode):
                    #if canImport(UIKit)
                    UIPasteboard.general.string = newCode
                    #else
                    return
                    #endif
                default:
                    return
                }
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
    }

    func sendMessage(message: WatchIOSMessageType) throws {
        guard session.isReachable, session.activationState == .activated else {
            throw AuthError.watchConnectivity(.companionNotReachable)
        }
        print("woot message sent: \(message)")

        let data = try encoder.encode(message)

        session.sendMessageData(data, replyHandler: nil)
    }
}
