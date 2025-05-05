//
//
// AuthLoginCoordinator.swift
// Proton Authenticator - Created on 25/04/2025.
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
//

import DataLayer
import Factory
import Foundation
import Macro
import Models
import ProtonCoreLogin
import ProtonCoreLoginUI
import SwiftUI

#if os(iOS)
struct UserLoginController: UIViewControllerRepresentable {
    let coordinator: CoordinatorProtocol

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = coordinator.rootViewController
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

@MainActor
protocol CoordinatorProtocol {
    var rootViewController: UIViewController { get }
}

@MainActor
final class AuthLoginCoordinator: CoordinatorProtocol {
    @LazyInjected(\ServiceContainer.userSessionManager) private var userSessionManager

    private lazy var welcomeViewController = makeWelcomeViewController()

    var rootViewController: UIViewController { welcomeViewController }
    private let logger: any LoggerProtocol

    private lazy var logInAndSignUp = makeLoginAndSignUp()

    init(logger: any LoggerProtocol) {
        self.logger = logger
    }

    func makeWelcomeViewController() -> UIViewController {
        let welcomeViewController = createLoginFlow()

        return welcomeViewController
    }

    func createLoginFlow() -> UIViewController {
        UIHostingController(rootView: UserLoginView(onAction: { [weak self] signUp in
            guard let self else { return }
            beginAddAccountFlow(isSigningUp: signUp)
        }))
    }

    func beginAddAccountFlow(isSigningUp: Bool) {
        let options = LoginCustomizationOptions(inAppTheme: {
            .default
        })
        if isSigningUp {
            logInAndSignUp.presentSignupFlow(over: rootViewController,
                                             customization: options) { [weak self] result in
                guard let self else { return }
                handle(result)
            }
        } else {
            logInAndSignUp.presentLoginFlow(over: rootViewController,
                                            customization: options) { [weak self] result in
                guard let self else { return }
                handle(result)
            }
        }
    }

    func makeLoginAndSignUp() -> LoginAndSignup {
        let signUpParameters = SignupParameters(separateDomainsButton: true,
                                                passwordRestrictions: .default,
                                                summaryScreenVariant: .noSummaryScreen)
        return .init(appName: "Proton Authenticator",
                     clientApp: .other(named: "Proton Authenticator"),
                     apiService: userSessionManager.apiService,
                     minimumAccountType: .external,
                     paymentsAvailability: .notAvailable,
                     signupAvailability: .available(parameters: signUpParameters))
    }

    func handle(_ result: LoginResult) {
        switch result {
        case .dismissed:
            return
        case let .loggedIn(logInData), let .signedUp(logInData):
            logInAndSignUp = makeLoginAndSignUp()
            Task { [weak self] in
                guard let self else { return }
                do {
                    try await userSessionManager.save(logInData)
                } catch {
                    logger.log(.error, category: .data, error.localizedDescription)
                }
            }
        }
    }
}
#endif
