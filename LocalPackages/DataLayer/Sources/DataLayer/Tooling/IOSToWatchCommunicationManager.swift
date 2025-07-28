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
    private let logger: any LoggerProtocol

    public init(session: WCSession = .default,
                entryDataService: any EntryDataServiceProtocol,
                logger: any LoggerProtocol) {
        self.session = session
        decoder = JSONDecoder()
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        self.entryDataService = entryDataService
        self.logger = logger
        super.init()
        self.session.delegate = self
        self.session.activate()
    }

    public func checkIfActive() {
        guard WCSession.isSupported(),
              session.activationState != .activated else {
            return
        }
        session.activate()
    }

    public func sessionDidBecomeInactive(_ session: WCSession) {}

    public func sessionDidDeactivate(_ session: WCSession) {}

    public func session(_ session: WCSession,
                        activationDidCompleteWith activationState: WCSessionActivationState,
                        error: (any Error)?) {}

    public func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        do {
            let message = try decoder.decode(WatchIOSMessageType.self, from: messageData)
            parseMessage(message: message)
        } catch {
            logger.log(.warning, category: .network, "Couldn't decode WCSession message: \(error)")
        }
    }
}

private extension IOSToWatchCommunicationManager {
    func parseMessage(message: WatchIOSMessageType) {
        Task { [weak self] in
            guard let self else { return }
            switch message {
            case .syncData:
                let entries = await entryDataService.extractingOrderedEntry()
                sendAllPages(entries: entries)
            case let .code(newCode):
                #if canImport(UIKit)
                UIPasteboard.general.string = newCode
                #else
                return
                #endif
            default:
                return
            }
        }
    }

    func sendAllPages(entries: [OrderedEntry]) {
        let pageSize = 100
        let requestId = UUID().uuidString
        let totalPages = Int(ceil(Double(entries.count) / Double(pageSize)))

        for page in 0..<totalPages {
            let startIndex = page * pageSize
            let endIndex = min(startIndex + pageSize, entries.count)
            let pageEntries = Array(entries[startIndex..<endIndex])

            let paginatedData = PaginatedWatchDataCommunication(requestId: requestId,
                                                                orderedEntries: pageEntries,
                                                                currentPage: page,
                                                                totalPages: totalPages,
                                                                isLastPage: page == totalPages - 1)

            sendMessage(message: .dataContent(paginatedData))
        }
    }

    func sendMessage(message: WatchIOSMessageType) {
        do {
            guard session.isReachable, session.activationState == .activated else {
                throw AuthError.watchConnectivity(.companionNotReachable)
            }

            let data = try encoder.encode(message)
            session.sendMessageData(data, replyHandler: nil)
        } catch {
            logger.log(.warning, category: .network, "Couldn't encode WCSession message: \(error)")
        }
    }
}
