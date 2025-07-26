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
    private var currentRequestId: String?
    private var receivedPages: [Int: [OrderedEntry]] = [:]
    private var expectedTotalPages: Int = 0
    private let session: WCSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var timeoutPublisher: AnyCancellable?

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
                 error: (any Error)?) {
        if let error {
            communicationState
                .send(.responseReceived(.failure(AuthError
                        .watchConnectivity(.sessionActivationFailed(error.localizedDescription)))))
        }
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        cancelTimeout()
        do {
            let message = try decoder.decode(WatchIOSMessageType.self, from: messageData)
            guard case let .dataContent(paginatedData) = message else {
                return
            }
            handleIncomingPage(paginatedData)
        } catch {
            handleError(error)
        }
    }

    // MARK: - WatchCommunicationServiceProtocol

    func sendMessage(message: WatchIOSMessageType) throws {
//         guard session.activationState == .activated else {
//             throw AuthError.watchConnectivity(.sessionNotActivated)
//         }
//
//         guard session.isPaired else {
//             communicationState.send(.responseReceived(.failure(
//                 AuthError.watchConnectivity(.notPaired)
//             )))
//             throw AuthError.watchConnectivity(.notPaired)
//         }
//
//         guard session.isReachable else {
//             communicationState.send(.responseReceived(.failure(
//                 AuthError.watchConnectivity(.companionNotReachable)
//             )))
//             throw AuthError.watchConnectivity(.companionNotReachable)
//         }

        switch message {
        case .syncData:
            startTimeoutTimer()
        default:
            break
        }

        let data = try encoder.encode(message)
        session.sendMessageData(data, replyHandler: nil)
    }

//    func sendMessage(message: WatchIOSMessageType) throws {
//        guard session.isReachable else {
//            throw AuthError.watchConnectivity(.companionNotReachable)
//        }
//        let data = try encoder.encode(message)
//
//        communicationState.send(.waitingForMessage)
//        session.sendMessageData(data, replyHandler: nil)
//    }
}

private extension WatchToIOSCommunicationManager {
    func handleError(_ error: Error) {
        communicationState
            .send(.responseReceived(.failure(AuthError
                    .watchConnectivity(.messageDecodingFailed(error.localizedDescription)))))
    }

    private func handleIncomingPage(_ data: PaginatedWatchDataCommunication) {
        // New request
        if currentRequestId != data.requestId {
            resetPaginationState()
            currentRequestId = data.requestId
            expectedTotalPages = data.totalPages
        }

        // Store the received page
        receivedPages[data.currentPage] = data.orderedEntries

        if data.isLastPage || receivedPages.count == expectedTotalPages {
            assembleCompleteData()
        } else {
            startTimeoutTimer() // Reset timer for next page
        }
    }

    func assembleCompleteData() {
        var completeData: [OrderedEntry] = []
        for page in 0..<expectedTotalPages {
            completeData.append(contentsOf: receivedPages[page] ?? [])
        }

        communicationState.send(.responseReceived(.success(completeData)))
        resetPaginationState()
    }

    func resetPaginationState() {
        cancelTimeout()
        currentRequestId = nil
        receivedPages.removeAll()
        expectedTotalPages = 0
        communicationState.send(.idle)
    }

    private func cancelTimeout() {
        timeoutPublisher = nil
    }

    private func startTimeoutTimer() {
        cancelTimeout()

        timeoutPublisher = Timer.publish(every: 10.0, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                communicationState.send(.responseReceived(.failure(AuthError.watchConnectivity(.timeout))))
                resetPaginationState()
            }
    }
}
