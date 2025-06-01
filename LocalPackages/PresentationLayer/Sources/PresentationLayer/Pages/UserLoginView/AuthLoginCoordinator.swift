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

#if os(iOS)
import DataLayer
import FactoryKit
import Foundation
import Macro
import Models
import ProtonCoreLogin
import ProtonCoreLoginUI
import SwiftUI

struct UserMobileLoginController: UIViewControllerRepresentable {
    let coordinator: any MobileCoordinatorProtocol

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        coordinator.rootViewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

@MainActor
protocol MobileCoordinatorProtocol {
    var rootViewController: UIViewController { get }
}

@MainActor
final class MobileLoginCoordinator: MobileCoordinatorProtocol {
    @LazyInjected(\ServiceContainer.userSessionManager) private var userSessionManager

    private lazy var welcomeViewController = createLoginFlow()

    var rootViewController: UIViewController { welcomeViewController }
    private let logger: any LoggerProtocol

    private lazy var logInAndSignUp = makeLoginAndSignUp()

    init(logger: any LoggerProtocol) {
        self.logger = logger
    }

    func createLoginFlow() -> UIViewController {
        UIHostingController(rootView: UserLoginView(onLogin: { [weak self] in
            guard let self else { return }
            logInAndSignUp.presentLoginFlow(over: rootViewController,
                                            customization: .empty) { [weak self] result in
                guard let self else { return }
                handle(result)
            }
        }, onCreateNewAccount: { [weak self] in
            guard let self else { return }
            logInAndSignUp.presentSignupFlow(over: rootViewController,
                                             customization: .empty) { [weak self] result in
                guard let self else { return }
                handle(result)
            }
        }))
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
