//
// RemoteEncryptedEntry.swift
// Proton Authenticator - Created on 13/05/2025.
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

public struct RemoteEncryptedEntry: Decodable, Equatable, Sendable {
    public let entryID: String
    public let authenticatorKeyID: String
    public let revision: Int
    public let contentFormatVersion: Int
    public let content: String
    public let flags: Int
    public let createTime: Int
    public let modifyTime: Int

    public init(entryID: String,
                authenticatorKeyID: String,
                revision: Int,
                contentFormatVersion: Int,
                content: String,
                flags: Int,
                createTime: Int,
                modifyTime: Int) {
        self.entryID = entryID
        self.authenticatorKeyID = authenticatorKeyID
        self.revision = revision
        self.contentFormatVersion = contentFormatVersion
        self.content = content
        self.flags = flags
        self.createTime = createTime
        self.modifyTime = modifyTime
    }
}
