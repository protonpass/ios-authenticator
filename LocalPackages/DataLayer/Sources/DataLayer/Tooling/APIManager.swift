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
import ProtonCoreCryptoGoImplementation
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

    public init(bundle: Bundle = .main,
                userDefaults: UserDefaults = kSharedUserDefaults) {
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

    public init(appVersion: String, doh: any DoHInterface = AuthDoH()) {
        self.appVersion = appVersion
        self.doh = doh
    }
}

public protocol APIManagerProtocol: Sendable {
    var apiService: APIService { get }
}

final class ForceUpgradeControllerImpl: ForceUpgradeController {
    func performForceUpgrade(message: String, config: ForceUpgradeConfig,
                             responseDelegate: ForceUpgradeResponseDelegate?) {}
}

public final class APIManager: @unchecked Sendable, APIManagerProtocol {
    private let logger: any LoggerProtocol
    private let configuration: APIManagerConfiguration
    private let forceUpgradeHelper: ForceUpgradeHelper
    private let keyStore: any KeychainServicing
    public let key = "credentials"
    #if os(iOS)
    private let challengeProvider = ChallengeParametersProvider.forAPIService(clientApp: .other(named:
        "authenticator"),
    challenge: .init())

    #elseif os(macOS)
    private let challengeProvider = ChallengeParametersProvider(prefix: "authenticator",
                                                                provideParametersForLoginAndSignup: { [] },
                                                                provideParametersForSessionFetching: { [] })
//        .forAPIService(clientApp: .other(named:
//        "authenticator"),
//    challenge: .init())

    #endif

    private let cachedCredentials: LegacyMutex<Credentials?> = .init(nil)
    public private(set) var apiService: APIService

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
            let credentials: Credentials = try keyStore.get(key: key, ofType: .generic, shouldSync: false)
            cachedCredentials.modify {
                $0 = credentials
            }

            newApiService = PMAPIService.createAPIService(doh: configuration.doh,
                                                          sessionUID: credentials.credential.UID,
                                                          challengeParametersProvider: challengeProvider)

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
        print("saving tokens")
        do {
//             let symmetricKey = try symmetricKeyProvider.getSymmetricKey()
//            let data = try JSONEncoder().encode(cachedCredentials.value)
//             let encryptedContent = try symmetricKey.encrypt(data)
            try keyStore.set(cachedCredentials.value, for: key, shouldSync: false)
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

    public func onSessionObtaining(credential: ProtonCoreNetworking.Credential) {
        log(.info, "Obtained Session credentials with session id \(credential.UID)")
        let credentials = getCredentials(credential: credential)
        cachedCredentials.modify {
            $0 = credentials
        }
        saveCachedCredentialsToKeychain()
        updateSession(sessionId: credential.UID)
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
        saveCachedCredentialsToKeychain()
        updateSession(sessionId: sessionUID)
    }

    public func onAuthenticatedSessionInvalidated(sessionUID: String) {
        log(.info, "Authenticated session invalidated for session id \(sessionUID)")
        cleanSession(sessionUID: sessionUID)
//        cachedCredentials.modify {
//            $0 = nil
//        }
//        saveCachedCredentialsToKeychain()
//        createApiService(credential: cachedCredentials.value)
//        authSessionInvalidatedDelegateForLoginAndSignup?
//            .sessionWasInvalidated(for: sessionUID,
//                                   isAuthenticatedSession: true)
    }

    public func onUnauthenticatedSessionInvalidated(sessionUID: String) {
        log(.info, "Unauthenticated session invalidated for session id \(sessionUID)")
        cleanSession(sessionUID: sessionUID)
    }

    func cleanSession(sessionUID: String) {
        cachedCredentials.modify {
            $0 = nil
        }
        saveCachedCredentialsToKeychain()
        createApiService(credential: nil)
        authSessionInvalidatedDelegateForLoginAndSignup?
            .sessionWasInvalidated(for: sessionUID,
                                   isAuthenticatedSession: false)
    }
}

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
