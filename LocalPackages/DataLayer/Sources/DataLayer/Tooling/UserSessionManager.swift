//
// UserSessionManager.swift
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

// periphery:ignore:all

import Combine
import CommonUtilities
import Foundation
import Models
import ProtonCoreChallenge
import ProtonCoreCrypto
import ProtonCoreCryptoGoImplementation
@preconcurrency import ProtonCoreCryptoGoInterface
import ProtonCoreDataModel
import ProtonCoreDoh
@preconcurrency import ProtonCoreEnvironment
@preconcurrency import ProtonCoreForceUpgrade
@preconcurrency import ProtonCoreFoundations
import ProtonCoreHumanVerification
import ProtonCoreKeyManager
import ProtonCoreLogin
@preconcurrency import ProtonCoreNetworking
@preconcurrency import ProtonCoreObservability
@preconcurrency import ProtonCoreServices
import SimplyPersist

public struct APIManagerConfiguration: Sendable {
    let appVersion: String
    let doh: any DoHInterface

    public init(appVersion: String, doh: any DoHInterface) {
        self.appVersion = appVersion
        self.doh = doh
    }
}

public protocol APIManagerProtocol: Sendable {
    var isAuthenticated: CurrentValueSubject<Bool, Never> { get }
    var apiService: APIService { get }

    func logout() async throws
}

public protocol UserInfoProviding: Sendable {
    var userData: UserData? { get }
    // periphery:ignore
    func getUserData() async throws -> UserData?
    func save(_ userData: UserData) async throws
    func userKeyEncrypt<T: Codable>(object: T) throws -> String
//    func userKeyDecrypt<T: Codable>(encryptedData: Data) throws -> T
}

public typealias UserSessionTooling = APIManagerProtocol & UserInfoProviding

public final class UserSessionManager: @unchecked Sendable, UserSessionTooling {
    private let logger: any LoggerProtocol
    private let configuration: APIManagerConfiguration
    private let forceUpgradeHelper: ForceUpgradeHelper
    private let keychain: any KeychainServicing
    private let encryptionService: any EncryptionServicing
    private let userDataProvider: any UserDataProvider
    private let credentialsKey = "credentials"

    #if os(iOS)
    private let challengeProvider = ChallengeParametersProvider.forAPIService(clientApp: .other(named:
        "authenticator"),
    challenge: .init())

    #elseif os(macOS)
    private let challengeProvider = ChallengeParametersProvider(prefix: "authenticator",
                                                                provideParametersForLoginAndSignup: { [] },
                                                                provideParametersForSessionFetching: { [] })
    #endif

    private let cachedCredentials: LegacyMutex<Credentials?> = .init(nil)
    private let cachedUserData: LegacyMutex<UserData?> = .init(nil)

    public nonisolated let isAuthenticated = CurrentValueSubject<Bool, Never>(false)
    public private(set) var apiService: APIService

    // swiftlint:disable:next identifier_name
    public var authSessionInvalidatedDelegateForLoginAndSignup: (any ProtonCoreServices
        .AuthSessionInvalidatedDelegate)?

    public var userData: UserData? {
        cachedUserData.value
    }

    public init(configuration: APIManagerConfiguration,
                keychain: any KeychainServicing,
                encryptionService: any EncryptionServicing,
                userDataProvider: any UserDataProvider,
                logger: any LoggerProtocol) {
        self.configuration = configuration
        self.logger = logger
        self.userDataProvider = userDataProvider
        self.encryptionService = encryptionService
        self.keychain = keychain
        Self.setUpCertificatePinning()
        injectDefaultCryptoImplementation()

        if let appStoreUrl = URL(string: AppConstants.appStoreUrl) {
            #if os(iOS)
            forceUpgradeHelper = .init(config: .mobile(appStoreUrl))

            #elseif os(macOS)
            forceUpgradeHelper = ForceUpgradeHelper(config: .mobile(appStoreUrl),
                                                    controller: ForceUpgradeControllerImpl())

            #endif
        } else {
            // Should never happen
            let message = "Can not parse App Store URL"
            assertionFailure(message)
            logger.log(.error, category: .network, "Can not parse App Store URL")
            #if os(iOS)
            forceUpgradeHelper = .init(config: .desktop)
            #elseif os(macOS)
            forceUpgradeHelper = ForceUpgradeHelper(config: .desktop, controller: ForceUpgradeControllerImpl())

            #endif
        }
        let newApiService: PMAPIService

        do {
            let encryptedContent: Data = try keychain.get(key: credentialsKey, ofType: .generic, shouldSync: false)
            let credentials: Credentials = try encryptionService.symmetricDecrypt(encryptedData: encryptedContent)

            cachedCredentials.modify {
                $0 = credentials
            }

            newApiService = PMAPIService.createAPIService(doh: configuration.doh,
                                                          sessionUID: credentials.credential.UID,
                                                          challengeParametersProvider: challengeProvider)
            isAuthenticated.send(!credentials.credential.isForUnauthenticatedSession)
        } catch {
            logger.log(.error, category: .network, "Couldn't get credentials from keychain: \(error)")
            newApiService = PMAPIService.createAPIServiceWithoutSession(doh: configuration.doh,
                                                                        challengeParametersProvider: challengeProvider)
        }

        #if os(iOS)

        let humanHelper =
            HumanCheckHelper(apiService: newApiService,
                             inAppTheme: { .default },
                             clientApp: .other(named: "authenticator"))
        #elseif os(macOS)
        let humanHelper = HumanCheckHelper(apiService: newApiService, clientApp: .other(named: "authenticator"))
        #endif
        newApiService.humanDelegate = humanHelper

        newApiService.forceUpgradeDelegate = forceUpgradeHelper
        apiService = newApiService
        apiService.authDelegate = self
        apiService.serviceDelegate = self
        (apiService as? PMAPIService)?.loggingDelegate = self
        updateTools()
        Task {
            _ = try? await getUserData()
        }
    }

    public func logout() async throws {
        log(.info, "Logging out")
        cachedCredentials.modify {
            $0 = nil
        }
        removeCachedCredentials()
        createApiService(credential: nil)
        try await userDataProvider.removeAllUsers()
        isAuthenticated.send(false)
    }
}

// MARK: - Utils

private extension UserSessionManager {
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

        #if os(iOS)

        let humanHelper =
            HumanCheckHelper(apiService: newApiService,
                             inAppTheme: { .default },
                             clientApp: .other(named: "authenticator"))
        #elseif os(macOS)
        let humanHelper = HumanCheckHelper(apiService: newApiService, clientApp: .other(named: "authenticator"))
        #endif
        newApiService.humanDelegate = humanHelper

        newApiService.loggingDelegate = self
        newApiService.forceUpgradeDelegate = forceUpgradeHelper
        apiService = newApiService
        updateTools()
    }

    func log(_ level: LogLevel, _ message: String, function: String = #function, line: Int = #line) {
        logger.log(level, category: .network, message, function: function, line: line)
    }

    func updateTools() {
        ObservabilityEnv.current.setupWorld(requestPerformer: apiService)
    }

    func getCredentials(credential: Credential,
                        authCredential: AuthCredential? = nil) -> Credentials {
        Credentials(credential: credential,
                    authCredential: authCredential ?? AuthCredential(credential))
    }

    func saveDataToKeychain(data: some Codable, for key: String) {
        do {
            let encryptedContent = try encryptionService.symmetricEncrypt(object: data)
            try keychain.set(encryptedContent, for: key, shouldSync: false)
        } catch {
            log(.error, "Failed to saved user sessions in keychain: \(error)")
        }
    }

    func removeCachedCredentials() {
        do {
            try keychain.delete(credentialsKey)
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

extension UserSessionManager: AuthDelegate {
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
        saveDataToKeychain(data: cachedCredentials.value, for: credentialsKey)
        updateSession(sessionId: sessionUID)
        isAuthenticated.send(!credential.isForUnauthenticatedSession)
    }

    public func onSessionObtaining(credential: ProtonCoreNetworking.Credential) {
        log(.info, "Obtained Session credentials with session id \(credential.UID)")
        let credentials = getCredentials(credential: credential)
        cachedCredentials.modify {
            $0 = credentials
        }
        saveDataToKeychain(data: cachedCredentials.value, for: credentialsKey)

        updateSession(sessionId: credential.UID)
        isAuthenticated.send(!credential.isForUnauthenticatedSession)
    }

    public func onAdditionalCredentialsInfoObtained(sessionUID: String,
                                                    password: String?,
                                                    salt: String?,
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
        saveDataToKeychain(data: cachedCredentials.value, for: credentialsKey)

        updateSession(sessionId: sessionUID)
    }

    public func onAuthenticatedSessionInvalidated(sessionUID: String) {
        log(.info, "Authenticated session invalidated for session id \(sessionUID)")
        cleanSession(sessionUID: sessionUID)
    }

    public func onUnauthenticatedSessionInvalidated(sessionUID: String) {
        log(.info, "Unauthenticated session invalidated for session id \(sessionUID)")
        cleanSession(sessionUID: sessionUID)
    }

    func cleanSession(sessionUID: String?) {
        Task { [weak self] in
            guard let self else {
                return
            }
            do {
                try await logout()
                if let sessionUID {
                    authSessionInvalidatedDelegateForLoginAndSignup?
                        .sessionWasInvalidated(for: sessionUID,
                                               isAuthenticatedSession: false)
                }
            } catch {
                log(.error, error.localizedDescription)
            }
        }
    }
}

// MARK: - APIServiceDelegate

extension UserSessionManager: APIServiceDelegate {
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

// MARK: - APIServiceLoggingDelegate

extension UserSessionManager: APIServiceLoggingDelegate {
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
        // swiftlint:disable line_length
        log(.error,
            "Access token refresh did fail for \(sessionType) session \(sessionID) with error: \(error.localizedDescription)")
        // swiftlint:enable line_length
    }
}

// MARK: - User data

public extension UserSessionManager {
    func getUserData() async throws -> UserData? {
        if let userData = cachedUserData.value {
            return userData
        }
        let userData = try await userDataProvider.getUserData()
        cachedUserData.modify { $0 = userData }

        return userData
    }

    func save(_ userData: UserData) async throws {
        try await userDataProvider.save(userData)
        cachedUserData.modify { $0 = userData }
    }

    func userKeyEncrypt(object: some Codable) throws -> String {
        guard let userData else {
            throw AuthError.generic(.missingUserData)
        }

        guard let userKey = userData.user.keys.first(where: { $0.active == 1 }) else {
            throw AuthError.crypto(.missingUserKey(userID: userData.user.ID))
        }

        guard let passphrase = userData.passphrases[userKey.keyID] else {
            throw AuthError.crypto(.missingPassphrase(keyID: userKey.keyID))
        }

        let publicKey = ArmoredKey(value: userKey.publicKey)
        let privateKey = ArmoredKey(value: userKey.privateKey)
        let signerKey = SigningKey(privateKey: privateKey,
                                   passphrase: .init(value: passphrase))

        let data = try JSONEncoder().encode(object)

        let encryptedData = try Encryptor.encrypt(publicKey: publicKey,
                                                  clearData: data,
                                                  signerKey: signerKey)
        return try encryptedData.unArmor().value.base64EncodedString()
    }
}

// MARK: - Tools and extension for user session management

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

    public init(bundle: Bundle = .main,
                userDefaults: UserDefaults) {
        var environment: AuthenticatorEnvironment = .black
        if bundle.isQaBuild {
            switch userDefaults.string(forKey: "pref_environment") {
            case "black":
                environment = .black
            case "prod":
                environment = .prod
            case "scientist":
                let name = userDefaults.string(forKey: "pref_scientist_env_name")
                environment = .scientist(name ?? "")

            default:
                // Fallback to "Automatic" mode
                #if DEBUG
                environment = .black
                #else
                environment = .prod
                #endif
            }
        } else {
            // Always point to prod when not in QA build
            environment = .prod
        }
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

final class ForceUpgradeControllerImpl: ForceUpgradeController {
    func performForceUpgrade(message: String,
                             config: ForceUpgradeConfig,
                             responseDelegate: ForceUpgradeResponseDelegate?) {}
}
