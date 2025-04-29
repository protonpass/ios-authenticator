//
// APIManager.swift
// Proton Authenticator - Created on 28/04/2025.
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

import CommonUtilities
import Foundation
import Models
import ProtonCoreChallenge
@preconcurrency import ProtonCoreCryptoGoInterface
import ProtonCoreDataModel
import ProtonCoreDoh
@preconcurrency import ProtonCoreEnvironment
@preconcurrency import ProtonCoreForceUpgrade
@preconcurrency import ProtonCoreFoundations
import ProtonCoreHumanVerification
@preconcurrency import ProtonCoreNetworking
@preconcurrency import ProtonCoreObservability
@preconcurrency import ProtonCoreServices

public final class AuthDoH: DoH, ServerConfig {
    public let signupDomain: String
    public let captchaHost: String
    public let humanVerificationV3Host: String
    public let accountHost: String
    public let defaultHost: String
    // periphery:ignore
    public let apiHost: String
    public let defaultPath: String
    public let proxyToken: String?

    public init(environment: AuthenticatorEnvironment = .black,
                userDefaults: UserDefaults) {
        signupDomain = environment.parameters.signupDomain
        captchaHost = environment.parameters.captchaHost
        humanVerificationV3Host = environment.parameters.humanVerificationV3Host
        accountHost = environment.parameters.accountHost
        defaultHost = environment.parameters.defaultHost
        apiHost = environment.parameters.apiHost
        defaultPath = environment.parameters.defaultPath
        proxyToken = userDefaults.string(forKey: "pref_custom_env_proxy_token")?.nilIfEmpty
    }
}

// MARK: - Keychain codable wrappers for credential elements & extensions

public struct Credentials: Hashable, Sendable, Codable {
    public let credential: Credential
    public let authCredential: AuthCredential
}

extension Credential: Codable, @retroactive Hashable {
    private enum CodingKeys: String, CodingKey {
        case UID
        case accessToken
        case refreshToken
        case userName
        case userID
        case scopes
        case mailboxPassword
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(UID)
        hasher.combine(accessToken)
        hasher.combine(refreshToken)
        hasher.combine(userName)
        hasher.combine(userID)
        hasher.combine(scopes)
        hasher.combine(mailboxPassword)
    }

    public init(from decoder: any Decoder) throws {
        self.init(UID: "",
                  accessToken: "",
                  refreshToken: "",
                  userName: "",
                  userID: "",
                  scopes: [],
                  mailboxPassword: "")
        let values = try decoder.container(keyedBy: CodingKeys.self)
        UID = try values.decode(String.self, forKey: .UID)
        accessToken = try values.decode(String.self, forKey: .accessToken)
        refreshToken = try values.decode(String.self, forKey: .refreshToken)
        userName = try values.decode(String.self, forKey: .userName)
        userID = try values.decode(String.self, forKey: .userID)
        scopes = try values.decode([String].self, forKey: .scopes)
        mailboxPassword = try values.decode(String.self, forKey: .mailboxPassword)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(UID, forKey: .UID)
        try container.encode(accessToken, forKey: .accessToken)
        try container.encode(refreshToken, forKey: .refreshToken)
        try container.encode(userName, forKey: .userName)
        try container.encode(userID, forKey: .userID)
        try container.encode(scopes, forKey: .scopes)
        try container.encode(mailboxPassword, forKey: .mailboxPassword)
    }
}

public struct APIManagerConfiguration: Sendable {
    let appVersion: String
    let doh: any DoHInterface

    public init(appVersion: String, doh: any DoHInterface) {
        self.appVersion = appVersion
        self.doh = doh
    }
}

public protocol APIManagerProtocol: Sendable {
    var apiService: APIService! { get }
}

public final class APIManager: @unchecked Sendable, APIManagerProtocol {
    private let logger: any LoggerProtocol
    private let configuration: APIManagerConfiguration
    private let forceUpgradeHelper: ForceUpgradeHelper
    private let keyStore: any KeychainServicing
    public let key = "credentials"
    private let challengeProvider = ChallengeParametersProvider.forAPIService(clientApp: .other(named:
        "authenticator"),
    challenge: .init())

    private let cachedCredentials: LegacyMutex<Credentials?> = .init(nil)
    public private(set) var apiService: ProtonCoreServices.APIService!

    // swiftlint:disable:next identifier_name
    public var authSessionInvalidatedDelegateForLoginAndSignup: (any ProtonCoreServices
        .AuthSessionInvalidatedDelegate)?

    public init(configuration: APIManagerConfiguration,
                keyStore: any KeychainServicing,
                logger: any LoggerProtocol) {
        self.configuration = configuration
        self.logger = logger
        self.keyStore = keyStore
        Self.setUpCertificatePinning()

        if let appStoreUrl = URL(string: AppConstants.appStoreUrl) {
            forceUpgradeHelper = .init(config: .mobile(appStoreUrl))
        } else {
            // Should never happen
            let message = "Can not parse App Store URL"
            assertionFailure(message)
            logger.log(.error, category: .network, "Can not parse App Store URL")
            forceUpgradeHelper = .init(config: .desktop)
        }
        let credentials: Credentials? = try? keyStore.get(key: key, ofType: .generic, shouldSync: false)

        if let credentials {
            createApiService(credential: credentials.credential)

            cachedCredentials.modify {
                $0 = credentials
            }
        } else {
            createApiService(credential: nil)
        }
    }
}

// MARK: - Utils

private extension APIManager {
    static func setUpCertificatePinning() {
        TrustKitWrapper.setUp()
        let trustKit = TrustKitWrapper.current
        PMAPIService.trustKit = trustKit
        PMAPIService.noTrustKit = trustKit == nil
    }

    func createApiService(credential: Credential?) {
        let newApiService = if let credential {
            PMAPIService.createAPIService(doh: configuration.doh,
                                          sessionUID: credential.UID,
                                          challengeParametersProvider: challengeProvider)
        } else {
            PMAPIService.createAPIServiceWithoutSession(doh: configuration.doh,
                                                        challengeParametersProvider: challengeProvider)
        }

        newApiService.authDelegate = self
        newApiService.serviceDelegate = self

        let humanHelper = HumanCheckHelper(apiService: newApiService,
                                           inAppTheme: { .default },
                                           clientApp: .pass)
        newApiService.humanDelegate = humanHelper

        newApiService.loggingDelegate = self
        newApiService.forceUpgradeDelegate = forceUpgradeHelper
        apiService = newApiService
        updateTools()
    }

    func log(_ level: LogLevel, _ message: String) {
        logger.log(level, category: .network, message)
    }

    func updateTools() {
        ObservabilityEnv.current.setupWorld(requestPerformer: apiService)
    }

    func getCredentials(credential: Credential,
                        authCredential: AuthCredential? = nil) -> Credentials {
        Credentials(credential: credential,
                    authCredential: authCredential ?? AuthCredential(credential))
    }

    func saveCachedCredentialsToKeychain() {
        do {
//             let symmetricKey = try symmetricKeyProvider.getSymmetricKey()
            let data = try JSONEncoder().encode(cachedCredentials.value)
//             let encryptedContent = try symmetricKey.encrypt(data)
            try keyStore.set(data, for: key, shouldSync: false)
        } catch {
            log(.error, "Failed to saved user sessions in keychain: \(error)")
        }
    }

    func updateSession(sessionId: String) {
        if apiService.sessionUID.isEmpty {
            apiService.setSessionUID(uid: sessionId)
        }

        updateTools()

        log(.info, "Session credentials are updated")
    }
}

// MARK: - AuthDelegate

extension APIManager: AuthDelegate {
    public func authCredential(sessionUID: String) -> ProtonCoreNetworking.AuthCredential? {
        log(.info, "Getting authCredential for session id \(sessionUID)")
        guard let credentials = cachedCredentials.value, credentials.authCredential.sessionID == sessionUID else {
            return nil
        }
        return credentials.authCredential
    }

    public func credential(sessionUID: String) -> ProtonCoreNetworking.Credential? {
        log(.info, "Getting credential for session id \(sessionUID)")
        guard let credentials = cachedCredentials.value, credentials.authCredential.sessionID == sessionUID else {
            return nil
        }
        return credentials.credential
    }

    //    public func onUpdate(credential: Credential, sessionUID: String) {
    //        logger.info("Update Session credentials with session id \(sessionUID)")
    //        assertDidSetUp()
    //
    //        serialAccessQueue.sync {
    //            for passModule in PassModule.allCases {
    //                let key = CredentialsKey(sessionId: sessionUID, module: passModule)
    //                let newCredentials = getCredentials(credential: credential,
    //                                                    module: passModule)
    //                let newAuthCredential = newCredentials.authCredential
    //                    .updatedKeepingKeyAndPasswordDataIntact(credential: credential)
    //                cachedCredentials[key] = Credentials(credential: credential,
    //                                                     authCredential: newAuthCredential,
    //                                                     module: passModule)
    //            }
    //            saveCachedCredentialsToKeychain()
    //            sendCredentialUpdateInfo(sessionId: sessionUID)
    //        }
    //    }

    public func onUpdate(credential: ProtonCoreNetworking.Credential, sessionUID: String) {
        log(.info, "Update Session credentials with session id \(sessionUID)")
        guard let credentials = cachedCredentials.value, credentials.authCredential.sessionID == sessionUID else {
            return
        }
        let newCredentials = getCredentials(credential: credential)
        let newAuthCredential = newCredentials.authCredential
            .updatedKeepingKeyAndPasswordDataIntact(credential: credential)
        cachedCredentials.modify {
            $0 = Credentials(credential: credential, authCredential: newAuthCredential)
        }
        saveCachedCredentialsToKeychain()
        updateSession(sessionId: sessionUID)
    }

    //
    //    public func onSessionObtaining(credential: Credential) {
    //        logger.info("Obtained Session credentials with session id \(credential.UID)")
    //        assertDidSetUp()
    //
    //        serialAccessQueue.sync {
    //            // The forking of sessions should be done at this point in the future and any looping on Pass
    //            /module
    //            // should be removed
    //
    //            // Remove all existing credentials related to the same userID
    //            // This is to handle logging into the same account multiple times
    //            for (key, value) in cachedCredentials
    //                where value.credential.userID == credential.userID {
    //                cachedCredentials.removeValue(forKey: key)
    //            }
    //
    //            for passModule in PassModule.allCases {
    //                let key = CredentialsKey(sessionId: credential.UID, module: passModule)
    //                let newCredentials = getCredentials(credential: credential,
    //                                                    module: passModule)
    //                cachedCredentials[key] = newCredentials
    //            }
    //            saveCachedCredentialsToKeychain()
    //            sendCredentialUpdateInfo(sessionId: credential.UID)
    //        }
    //    }
    //
    public func onSessionObtaining(credential: ProtonCoreNetworking.Credential) {
        log(.info, "Obtained Session credentials with session id \(credential.UID)")
        let credentials = getCredentials(credential: credential)
        cachedCredentials.modify {
            $0 = credentials
        }
        saveCachedCredentialsToKeychain()
        updateSession(sessionId: credential.UID)
    }

    //    public func onAdditionalCredentialsInfoObtained(sessionUID: String,
    //                                                    password: String?,
    //                                                    salt: String?,
    //                                                    privateKey: String?) {
    //        logger.info("Additional credentials for session id \(sessionUID)")
    //        assertDidSetUp()
    //
    //        serialAccessQueue.sync {
    //            for passModule in PassModule.allCases {
    //                let key = CredentialsKey(sessionId: sessionUID, module: passModule)
    //                guard let element = cachedCredentials[key] else {
    //                    return
    //                }
    //
    //                if let password {
    //                    element.authCredential.update(password: password)
    //                }
    //                let saltToUpdate = salt ?? element.authCredential.passwordKeySalt
    //                let privateKeyToUpdate = privateKey ?? element.authCredential.privateKey
    //                element.authCredential.update(salt: saltToUpdate, privateKey: privateKeyToUpdate)
    //                cachedCredentials[key] = element
    //            }
    //            saveCachedCredentialsToKeychain()
    //            sendCredentialUpdateInfo(sessionId: sessionUID)
    //        }
    //    }
    public func onAdditionalCredentialsInfoObtained(sessionUID: String, password: String?, salt: String?,
                                                    privateKey: String?) {
        log(.info, "Additional credentials for session id \(sessionUID)")
        guard let credentials = cachedCredentials.value, credentials.authCredential.sessionID == sessionUID else {
            return
        }
        if let password {
            credentials.authCredential.update(password: password)
        }
        let saltToUpdate = salt ?? credentials.authCredential.passwordKeySalt
        let privateKeyToUpdate = privateKey ?? credentials.authCredential.privateKey
        credentials.authCredential.update(salt: saltToUpdate, privateKey: privateKeyToUpdate)
        cachedCredentials.modify { credentials in
            guard let credentials, credentials.authCredential.sessionID == sessionUID else {
                return
            }
            if let password {
                credentials.authCredential.update(password: password)
            }
            let saltToUpdate = salt ?? credentials.authCredential.passwordKeySalt
            let privateKeyToUpdate = privateKey ?? credentials.authCredential.privateKey
            credentials.authCredential.update(salt: saltToUpdate, privateKey: privateKeyToUpdate)
        }
        saveCachedCredentialsToKeychain()
        updateSession(sessionId: sessionUID)
    }

    //    public func onAuthenticatedSessionInvalidated(sessionUID: String) {
    //        logger.info("Authenticated session invalidated for session id \(sessionUID)")
    //        assertDidSetUp()
    //
    //        serialAccessQueue.sync {
    //            let key = CredentialsKey(sessionId: sessionUID, module: module)
    //            let currentSession = cachedCredentials[key]
    //            removeCredentials(for: sessionUID)
    //            saveCachedCredentialsToKeychain()
    //            sendSessionInvalidationInfo(sessionId: sessionUID, isAuthenticatedSession: true)
    //            _sessionWasInvalidated.send((sessionId: sessionUID, userId: currentSession?.credential.userID))
    //        }
    //    }
    //
    //    public func onUnauthenticatedSessionInvalidated(sessionUID: String) {
    //        logger.info("unauthenticated session invalidated for session id \(sessionUID)")
    //        assertDidSetUp()
    //
    //        serialAccessQueue.sync {
    //            let key = CredentialsKey(sessionId: sessionUID, module: module)
    //            let currentSession = cachedCredentials[key]
    //            removeCredentials(for: sessionUID)
    //            saveCachedCredentialsToKeychain()
    //            sendSessionInvalidationInfo(sessionId: sessionUID, isAuthenticatedSession: false)
    //            _sessionWasInvalidated.send((sessionId: sessionUID, userId: currentSession?.credential.userID))
    //        }
    //    }
    public func onAuthenticatedSessionInvalidated(sessionUID: String) {
        log(.info, "Authenticated session invalidated for session id \(sessionUID)")
        cachedCredentials.modify {
            $0 = nil
        }
        createApiService(credential: nil)
        authSessionInvalidatedDelegateForLoginAndSignup?
            .sessionWasInvalidated(for: sessionUID,
                                   isAuthenticatedSession: true)
    }

    public func onUnauthenticatedSessionInvalidated(sessionUID: String) {
        log(.info, "Unauthenticated session invalidated for session id \(sessionUID)")
        cachedCredentials.modify {
            $0 = nil
        }
        createApiService(credential: nil)
        authSessionInvalidatedDelegateForLoginAndSignup?
            .sessionWasInvalidated(for: sessionUID,
                                   isAuthenticatedSession: false)
    }
}

// extension APIManager: AuthHelperDelegate {
//    public func sessionWasInvalidated(for sessionUID: String, isAuthenticatedSession: Bool) {
////        allCurrentApiServices.removeAll { $0.apiService.sessionUID == sessionUID }
////        if allCurrentApiServices.isEmpty {
////            getUnauthApiService()
////        }
//        createApiService(credential: nil)
//        if isAuthenticatedSession {
//            logger.log(.info, category: .network, "Authenticated session is invalidated. Logging out.")
//        } else {
//            logger.log(.info, category: .network, "Unauthenticated session is invalidated. Credentials are
//            erased, fetching new ones")
//        }
//    }
//
//    public func credentialsWereUpdated(authCredential: AuthCredential,
//                                       credential: Credential,
//                                       for sessionUID: String) {
//        if allCurrentApiServices.contains(where: { $0.apiService.sessionUID == sessionUID }) {
//            // Credentials already exist
//            // => update the related ApiService
//            allCurrentApiServices = allCurrentApiServices.map { element in
//                guard element.apiService.sessionUID == sessionUID else {
//                    return element
//                }
//
//                return element.copy(isAuthenticated: !authCredential.isForUnauthenticatedSession)
//            }
//        } else if allCurrentApiServices.contains(where: \.apiService.sessionUID.isEmpty) {
//            allCurrentApiServices = allCurrentApiServices.map { element in
//                guard element.apiService.sessionUID.isEmpty else {
//                    return element
//                }
//                element.apiService.setSessionUID(uid: sessionUID)
//                return element
//            }
//        } else {
//            // Credentials not yet exist
//            // => make a new ApiService
//            allCurrentApiServices.append(makeAPIManagerElements(credential: credential))
//        }
//
//        if apiService.sessionUID.isEmpty {
//            apiService.setSessionUID(uid: sessionUID)
//        }
//
//        updateTools()
//
//      log(.info, "Session credentials are updated")
//    }
//
//    func updateTools() {
//        ObservabilityEnv.current.setupWorld(requestPerformer: apiService)
//    }
// }

// MARK: - APIServiceDelegate

extension APIManager: APIServiceDelegate {
    public var appVersion: String { configuration.appVersion }
    public var userAgent: String? { UserAgent.default.ua }
    public var locale: String { Locale.autoupdatingCurrent.identifier }
    public var additionalHeaders: [String: String]? { nil }

    public func onDohTroubleshot() {}

    public func onUpdate(serverTime: Int64) {
        CryptoGo.CryptoUpdateTime(serverTime)
    }

    public func isReachable() -> Bool {
        // swiftlint:disable:next todo
        // TODO: Handle this
        true
    }
}

//

// MARK: - APIServiceLoggingDelegate

extension APIManager: APIServiceLoggingDelegate {
    public func accessTokenRefreshDidStart(for sessionID: String,
                                           sessionType: APISessionTypeForLogging) {
        log(.info, "Access token refresh did start for \(sessionType) session \(sessionID)")
    }

    public func accessTokenRefreshDidSucceed(for sessionID: String,
                                             sessionType: APISessionTypeForLogging,
                                             reason: APIServiceAccessTokenRefreshSuccessReasonForLogging) {
        log(.info, """
        Access token refresh did succeed for \(sessionType) session \(sessionID)
        with reason \(reason)
        """)
    }

    public func accessTokenRefreshDidFail(for sessionID: String,
                                          sessionType: APISessionTypeForLogging,
                                          error: APIServiceAccessTokenRefreshErrorForLogging) {
        log(.error,
            "Access token refresh did fail for \(sessionType) session \(sessionID) with error: \(error.localizedDescription)")
    }
}

//
//
// public protocol AuthManagerProtocol: Sendable, AuthDelegate {
//    var sessionWasInvalidated: AnyPublisher<(sessionId: String, userId: String?), Never> { get }
//
//    func setUp()
//    func setUpDelegate(_ delegate: any AuthHelperDelegate)
//    func getCredential(userId: String) -> AuthCredential?
//    // periphery:ignore
//    func clearSessions(sessionId: String)
//    // periphery:ignore
//    func clearSessions(userId: String)
//    func getAllCurrentCredentials() -> [Credential]
//    func removeCredentials(userId: String)
//    func removeAllCredentials()
// }
//
// public extension AuthManagerProtocol {
//    func isAuthenticated(userId: String) -> Bool {
//        guard let credential = getCredential(userId: userId) else {
//            return false
//        }
//        return !credential.isForUnauthenticatedSession
//    }
// }
//
// public final class AuthManager: @unchecked Sendable, AuthManagerProtocol {
//    public private(set) weak var delegate: (any AuthHelperDelegate)?
//    // swiftlint:disable:next identifier_name
//    public weak var authSessionInvalidatedDelegateForLoginAndSignup: (any AuthSessionInvalidatedDelegate)?
//    public static let storageKey = "AuthManagerStorageKey"
//    private let serialAccessQueue = DispatchQueue(label: "me.proton.pass.authmanager")
//
//    private typealias CachedCredentials = [CredentialsKey: Credentials]
//
//    private var cachedCredentials: CachedCredentials = [:]
//    private let keychain: any KeychainProtocol
//    private let symmetricKeyProvider: any NonAsyncSymmetricKeyProvider
//    private let module: PassModule
//    private let _sessionWasInvalidated: PassthroughSubject<(sessionId: String, userId: String?), Never> = .init()
//    private let logger: Logger
//    private var didSetUp = false
//
//    // This exposes a read only publisher to the rest of the application as AnyPublisher has no send function
//    public var sessionWasInvalidated: AnyPublisher<(sessionId: String, userId: String?), Never> {
//        _sessionWasInvalidated.eraseToAnyPublisher()
//    }
//
//    public init(keychain: any KeychainProtocol,
//                symmetricKeyProvider: any NonAsyncSymmetricKeyProvider,
//                module: PassModule,
//                logManager: any LogManagerProtocol) {
//        self.keychain = keychain
//        self.symmetricKeyProvider = symmetricKeyProvider
//        self.module = module
//        logger = .init(manager: logManager)
//    }
//
//    public func setUp() {
//        cachedCredentials = getCachedCredentials()
//        didSetUp = true
//    }
//
//    public func setUpDelegate(_ delegate: any AuthHelperDelegate) {
//        assertDidSetUp()
//        serialAccessQueue.sync {
//            self.delegate = delegate
//        }
//    }
//
//    public func getCredential(userId: String) -> AuthCredential? {
//        logger.info("getting authCredential for userId id \(userId)")
//        assertDidSetUp()
//
//        return serialAccessQueue.sync {
//            cachedCredentials
//                .first(where: { $0.key.module == module && $0.value.authCredential.userID == userId })?
//                .value.authCredential
//        }
//    }
//
//    public func removeCredentials(userId: String) {
//        logger.info("Removing credential for userId id \(userId)")
//        assertDidSetUp()
//
//        serialAccessQueue.sync {
//            cachedCredentials = cachedCredentials.filter { _, value in
//                value.credential.userID != userId
//            }
//            saveCachedCredentialsToKeychain()
//        }
//    }
//
//    public func removeAllCredentials() {
//        assertDidSetUp()
//        serialAccessQueue.sync {
//            cachedCredentials = [:]
//            saveCachedCredentialsToKeychain()
//        }
//    }
//

//    public func onAdditionalCredentialsInfoObtained(sessionUID: String,
//                                                    password: String?,
//                                                    salt: String?,
//                                                    privateKey: String?) {
//        logger.info("Additional credentials for session id \(sessionUID)")
//        assertDidSetUp()
//
//        serialAccessQueue.sync {
//            for passModule in PassModule.allCases {
//                let key = CredentialsKey(sessionId: sessionUID, module: passModule)
//                guard let element = cachedCredentials[key] else {
//                    return
//                }
//
//                if let password {
//                    element.authCredential.update(password: password)
//                }
//                let saltToUpdate = salt ?? element.authCredential.passwordKeySalt
//                let privateKeyToUpdate = privateKey ?? element.authCredential.privateKey
//                element.authCredential.update(salt: saltToUpdate, privateKey: privateKeyToUpdate)
//                cachedCredentials[key] = element
//            }
//            saveCachedCredentialsToKeychain()
//            sendCredentialUpdateInfo(sessionId: sessionUID)
//        }
//    }
//
//    public func onAuthenticatedSessionInvalidated(sessionUID: String) {
//        logger.info("Authenticated session invalidated for session id \(sessionUID)")
//        assertDidSetUp()
//
//        serialAccessQueue.sync {
//            let key = CredentialsKey(sessionId: sessionUID, module: module)
//            let currentSession = cachedCredentials[key]
//            removeCredentials(for: sessionUID)
//            saveCachedCredentialsToKeychain()
//            sendSessionInvalidationInfo(sessionId: sessionUID, isAuthenticatedSession: true)
//            _sessionWasInvalidated.send((sessionId: sessionUID, userId: currentSession?.credential.userID))
//        }
//    }
//
//    public func onUnauthenticatedSessionInvalidated(sessionUID: String) {
//        logger.info("unauthenticated session invalidated for session id \(sessionUID)")
//        assertDidSetUp()
//
//        serialAccessQueue.sync {
//            let key = CredentialsKey(sessionId: sessionUID, module: module)
//            let currentSession = cachedCredentials[key]
//            removeCredentials(for: sessionUID)
//            saveCachedCredentialsToKeychain()
//            sendSessionInvalidationInfo(sessionId: sessionUID, isAuthenticatedSession: false)
//            _sessionWasInvalidated.send((sessionId: sessionUID, userId: currentSession?.credential.userID))
//        }
//    }
//
//    public func clearSessions(sessionId: String) {
//        logger.info("Clear sessions for session id \(sessionId)")
//        assertDidSetUp()
//
//        serialAccessQueue.sync {
//            removeCredentials(for: sessionId)
//            saveCachedCredentialsToKeychain()
//        }
//    }
//
//    public func clearSessions(userId: String) {
//        logger.info("Clear sessions for user id \(userId)")
//        assertDidSetUp()
//
//        serialAccessQueue.sync {
//            cachedCredentials = cachedCredentials.filter { $0.value.credential.userID != userId }
//            saveCachedCredentialsToKeychain()
//        }
//    }
//
//    public func getAllCurrentCredentials() -> [Credential] {
//        assertDidSetUp()
//        return cachedCredentials.compactMap { key, element -> Credential? in
//            guard key.module == module else {
//                return nil
//            }
//            return element.credential
//        }
//    }
// }
//
// public extension AuthManager {
//    /// Introduced on July 2024 for multi accounts support. Can be removed later on.
//    func migrate(_ credential: AuthCredential) {
//        assertDidSetUp()
//        serialAccessQueue.sync {
//            for module in PassModule.allCases {
//                let key = CredentialsKey(sessionId: credential.sessionID, module: module)
//                cachedCredentials[key] = .init(credential: .init(credential),
//                                               authCredential: credential,
//                                               module: module)
//            }
//            saveCachedCredentialsToKeychain()
//        }
//    }
//
//    /// Introduced on February 2025 for CSV import support. Can be removed later on.
//    func initializeCredentialsForActionExtension() {
//        assertDidSetUp()
//        serialAccessQueue.sync {
//            if let appCredential = cachedCredentials.first(where: { $0.key.module == .hostApp }) {
//                let key = CredentialsKey(sessionId: appCredential.value.authCredential.sessionID,
//                                         module: .actionExtension)
//                cachedCredentials[key] = appCredential.value
//            }
//            saveCachedCredentialsToKeychain()
//        }
//    }
//
//    @_spi(QA)
//    func getAllCredentialsOfAllModules() -> [Credentials] {
//        assertDidSetUp()
//        return Array(cachedCredentials.values)
//    }
// }
//
//// MARK: - Utils
//
// private extension AuthManager {
//    func assertDidSetUp() {
//        assert(didSetUp, "AuthManager not set up. Call setUp() function as soon as possible.")
//        if !didSetUp {
//            logger.error("AuthManager not set up")
//        }
//    }
//

//
//    func sendCredentialUpdateInfo(sessionId: String) {
//        let key = CredentialsKey(sessionId: sessionId, module: module)
//        guard let credentials = cachedCredentials[key] else {
//            return
//        }
//
//        delegate?.credentialsWereUpdated(authCredential: credentials.authCredential,
//                                         credential: credentials.credential,
//                                         for: sessionId)
//    }
//
//    func sendSessionInvalidationInfo(sessionId: String, isAuthenticatedSession: Bool) {
//        delegate?.sessionWasInvalidated(for: sessionId,
//                                        isAuthenticatedSession: isAuthenticatedSession)
//        authSessionInvalidatedDelegateForLoginAndSignup?
//            .sessionWasInvalidated(for: sessionId,
//                                   isAuthenticatedSession: isAuthenticatedSession)
//    }
// }
//
//// MARK: - Storage
//
// private extension AuthManager {
//    func saveCachedCredentialsToKeychain() {
//        do {
//            let symmetricKey = try symmetricKeyProvider.getSymmetricKey()
//            let data = try JSONEncoder().encode(cachedCredentials)
//            let encryptedContent = try symmetricKey.encrypt(data)
//            try keychain.setOrError(encryptedContent, forKey: Self.storageKey)
//        } catch {
//            logger.error("Failed to saved user sessions in keychain: \(error)")
//        }
//    }
//
//    func getCachedCredentials() -> [CredentialsKey: Credentials] {
//        guard let encryptedContent = try? keychain.dataOrError(forKey: Self.storageKey),
//              let symmetricKey = try? symmetricKeyProvider.getSymmetricKey() else {
//            return [:]
//        }
//
//        do {
//            let decryptedContent = try symmetricKey.decrypt(encryptedContent)
//            return try JSONDecoder().decode(CachedCredentials.self, from: decryptedContent)
//        } catch {
//            logger.error("Failed to decrypted user sessions from keychain: \(error)")
//            try? keychain.removeOrError(forKey: Self.storageKey)
//            return [:]
//        }
//    }
//
//    func removeCredentials(for sessionUID: String) {
//        for module in PassModule.allCases {
//            let key = CredentialsKey(sessionId: sessionUID, module: module)
//            cachedCredentials[key] = nil
//        }
//    }
// }
//
//// MARK: - Keychain codable wrappers for credential elements & extensions
//
// public struct Credentials: Hashable, Sendable, Codable {
//    public let credential: Credential
//    public let authCredential: AuthCredential
//    public let module: PassModule
// }
//
// private struct CredentialsKey: Hashable, Codable {
//    let sessionId: String
//    let module: PassModule
// }
//
// extension Credential: Codable, @retroactive Hashable {
//    private enum CodingKeys: String, CodingKey {
//        case UID
//        case accessToken
//        case refreshToken
//        case userName
//        case userID
//        case scopes
//        case mailboxPassword
//    }
//
//    public func hash(into hasher: inout Hasher) {
//        hasher.combine(UID)
//        hasher.combine(accessToken)
//        hasher.combine(refreshToken)
//        hasher.combine(userName)
//        hasher.combine(userID)
//        hasher.combine(scopes)
//        hasher.combine(mailboxPassword)
//    }
//
//    public init(from decoder: any Decoder) throws {
//        self.init(UID: "",
//                  accessToken: "",
//                  refreshToken: "",
//                  userName: "",
//                  userID: "",
//                  scopes: [],
//                  mailboxPassword: "")
//        let values = try decoder.container(keyedBy: CodingKeys.self)
//        UID = try values.decode(String.self, forKey: .UID)
//        accessToken = try values.decode(String.self, forKey: .accessToken)
//        refreshToken = try values.decode(String.self, forKey: .refreshToken)
//        userName = try values.decode(String.self, forKey: .userName)
//        userID = try values.decode(String.self, forKey: .userID)
//        scopes = try values.decode([String].self, forKey: .scopes)
//        mailboxPassword = try values.decode(String.self, forKey: .mailboxPassword)
//    }
//
//    public func encode(to encoder: any Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(UID, forKey: .UID)
//        try container.encode(accessToken, forKey: .accessToken)
//        try container.encode(refreshToken, forKey: .refreshToken)
//        try container.encode(userName, forKey: .userName)
//        try container.encode(userID, forKey: .userID)
//        try container.encode(scopes, forKey: .scopes)
//        try container.encode(mailboxPassword, forKey: .mailboxPassword)
//    }
// }
