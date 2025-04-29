//
//
// UserLoginViewModel.swift
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

import Factory
import Foundation
import Macro
import Models
import ProtonCoreLogin
import ProtonCoreLoginUI
import SwiftUI

// @Observable
// @MainActor
// final class UserLoginViewModel: ObservableObject {
//    @ObservationIgnored
//    private weak var logInAndSignUp: LoginAndSignup?
//
//    @ObservationIgnored
//    @LazyInjected(\ServiceContainer.settingsService) private var settingsService
//
//    @ObservationIgnored
//    @Injected(\ServiceContainer.apiManager) private var apiManager
//
//    @ObservationIgnored
//    var rootViewController: UIViewController? { UIApplication.shared.topViewController() }
//
//    init() {
//        logInAndSignUp = makeLoginAndSignUp()
//        setUp()
//    }
//
////    func createRootViewController(view: some View) {
////        rootViewController = UIApplication.shared.topViewController() //UIHostingController(rootView: view) //
////        UIApplication.shared.topViewController() /
////    }
//
//    func beginAddAccountFlow(isSigningUp: Bool) {
////        guard let rootViewController else {
////            return
////        }
//        guard let rootVC = getRootViewController() else {
//            return
//        }
//
//        let options = LoginCustomizationOptions(inAppTheme: { [weak self] in
//            return .default
//        })
//        if isSigningUp {
//            logInAndSignUp?.presentSignupFlow(over: rootVC,
//                                              customization: options) { [weak self] result in
//                guard let self else { return }
//                handle(result)
//            }
//        } else {
//            logInAndSignUp?.presentLoginFlow(over: rootVC,
//                                             customization: options) { [weak self] result in
//                guard let self else { return }
//                handle(result)
//            }
//        }
//    }
//
//    func getRootViewController() -> UIViewController? {
//        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
//            return nil
//        }
//        return windowScene.windows.first?.rootViewController
//    }
// }

// private extension UserLoginViewModel {
//    func setUp() {}
//
//    func makeLoginAndSignUp() -> LoginAndSignup {
//        let signUpParameters = SignupParameters(separateDomainsButton: true,
//                                                passwordRestrictions: .default,
//                                                summaryScreenVariant: .noSummaryScreen)
//        return .init(appName: "Proton Authenticator",
//                     clientApp: .other(named: "Proton Authenticator"),
//                     apiService: apiManager.apiService,
//                     minimumAccountType: .external,
//                     paymentsAvailability: .notAvailable,
//                     signupAvailability: .available(parameters: signUpParameters))
//    }

//    func handle(_ result: LoginResult) {
//        switch result {
//        case .dismissed:
//            return
//        case let .loggedIn(logInData), let .signedUp(logInData):
//            print("woot logged in: \(logInData)")
//            logInAndSignUp = makeLoginAndSignUp()
////            handle(logInData: logInData)
//        }
//    }

//    func createLoginFlow() -> UIViewController {
////        if UserDefaults.standard.bool(forKey: Constants.QA.newLoginFlow) {
////            return UIHostingController(rootView: LoginOnboardingView(onAction: { [weak self] signUp in
////                guard let self else { return }
////                beginAddAccountFlow(isSigningUp: signUp)
////            }))
////        }
////
////        let loginVariant = abTestingManager.variant(for: "LoginFlowExperiment",
////                                                    type: LoginFlowExperiment.self,
////                                                    default: .new)
////        switch loginVariant {
////        case .new:
////            sendTelemetryEvent(.newLoginFlow(event: "fe.welcome.displayed", item: nil))
//        UIHostingController(rootView: LoginOnboardingView(onAction: { [weak self] signUp in
//            guard let self else { return }
//            beginAddAccountFlow(isSigningUp: signUp)
//        }))
////        default:
////            return WelcomeViewController(variant: .pass(.init(body: #localized("Secure password manager and
////            more"))),
////                                         delegate: self,
////                                         username: nil,
////                                         signupAvailable: true)
////        }
//    }
//
//    func makeWelcomeViewController() -> UIViewController {
//        let welcomeViewController = createLoginFlow()
//
//        return welcomeViewController
//    }
// }

// import Macro
// import ProtonCoreUIFoundations
// import SwiftUI
//
// public struct LoginOnboardingView: View {
//    private let onAction: (Bool) -> Void
//
//    public init(onAction: @escaping (_ signUp: Bool) -> Void) {
//        self.onAction = onAction
//    }
//
//    public var body: some View {
//        VStack(spacing: 0) {
//            Group {
//                bottomActionButton(signUp: true)
//                bottomActionButton(signUp: false)
//                    .padding(.vertical, 8)
//            }
//            .padding(.horizontal, 36)
//        }
//        .padding(.top, 20)
//    }
//
//    @ViewBuilder
//    func bottomActionButton(signUp: Bool) -> some View {
//        if signUp {
//            Button { onAction(signUp) } label: {
//                Text(#localized("Create an account", bundle: .module))
//            }
//
//        } else {
//            Button { onAction(signUp) } label: {
//                Text(#localized("Sign in", bundle: .module))
//            }
//        }
//    }
// }
//
// extension UIApplication {
//    func topViewController(controller: UIViewController? = UIApplication.shared.connectedScenes
//        .compactMap { ($0 as? UIWindowScene)?.keyWindow }
//        .first?.rootViewController) -> UIViewController? {
//        if let nav = controller as? UINavigationController {
//            return topViewController(controller: nav.visibleViewController)
//        }
//        if let tab = controller as? UITabBarController {
//            return topViewController(controller: tab.selectedViewController)
//        }
//        if let presented = controller?.presentedViewController {
//            return topViewController(controller: presented)
//        }
//        return controller
//    }
// }
#if os(iOS)

@MainActor
final class AuthLoginCoordinator {
    @Injected(\ServiceContainer.apiManager) private var apiManager

    private lazy var welcomeViewController = makeWelcomeViewController()

    var rootViewController: UIViewController { welcomeViewController }

    private lazy var logInAndSignUp = makeLoginAndSignUp()

    init() {}

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
                     apiService: apiManager.apiService,
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

            print("woot logged in")
//            handle(logInData: logInData)
        }
    }
}
#endif
