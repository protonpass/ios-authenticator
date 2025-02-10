//
//  Item.swift
//  Authenticator
//
//  Created by martin on 04/02/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date = Date.now

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
