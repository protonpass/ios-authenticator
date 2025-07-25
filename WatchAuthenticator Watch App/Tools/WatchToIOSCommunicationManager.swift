//
// WatchToIOSCommunicationManager.swift
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
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.

import Combine
import Foundation
import Models
import WatchConnectivity

enum CommunicationState: Equatable {
    case waitingForMessage
    case responseReceived(Result<[OrderedEntry], AuthError>)
    case idle
}

protocol WatchCommunicationServiceProtocol {
    var communicationState: CurrentValueSubject<CommunicationState, Never> { get }

    func sendMessage(message: WatchIOSMessageType) throws
}

final class WatchToIOSCommunicationManager: NSObject, WCSessionDelegate, WatchCommunicationServiceProtocol {
    let communicationState: CurrentValueSubject<CommunicationState, Never> = .init(.idle)
    private let session: WCSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: WCSession = .default) {
        self.session = session
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        encoder = JSONEncoder()
        super.init()
        self.session.delegate = self
        self.session.activate()
    }

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: (any Error)?) {}

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        do {
            let message = try decoder.decode(WatchIOSMessageType.self, from: messageData)
            guard case let .dataContent(content) = message else {
                return
            }
            communicationState.send(.responseReceived(.success(content)))
        } catch {
            communicationState
                .send(.responseReceived(.failure(AuthError
                        .watchConnectivity(.messageDecodingFailed(error.localizedDescription)))))
        }
    }

    func sendMessage(message: WatchIOSMessageType) throws {
        guard session.isReachable else {
            throw AuthError.watchConnectivity(.companionNotReachable)
        }
        let data = try encoder.encode(message)

        communicationState.send(.waitingForMessage)
        session.sendMessageData(data, replyHandler: nil)
    }
}
