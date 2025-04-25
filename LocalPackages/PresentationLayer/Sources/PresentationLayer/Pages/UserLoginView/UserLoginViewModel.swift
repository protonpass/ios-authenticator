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

import Foundation
import ProtonCoreLogin
import ProtonCoreLoginUI
import SwiftUI

@Observable
@MainActor
final class UserLoginViewModel {
    @ObservationIgnored
    private weak var logInAndSignUp: LoginAndSignup?

    init() {
        logInAndSignUp = makeLoginAndSignUp()
        setUp()
    }
    
    func beginAddAccountFlow(isSigningUp: Bool, rootViewController: some View) {
        let options = LoginCustomizationOptions(inAppTheme: { [weak self] in
            guard let self else { return .default }
//            return getSharedPreferences().theme.inAppTheme
        })
        if isSigningUp {
            logInAndSignUp?.presentSignupFlow(over: UIHostingController(rootView: rootViewController),
                                             customization: options) { [weak self] result in
                guard let self else { return }
                handle(result)
            }
        } else {
            logInAndSignUp?.presentLoginFlow(over: UIHostingController(rootView: rootViewController),
                                            customization: options) { [weak self] result in
                guard let self else { return }
                handle(result)
            }
        }
    }

}

private extension UserLoginViewModel {
    func setUp() {}
    
    func makeLoginAndSignUp() -> LoginAndSignup {
        let signUpParameters = SignupParameters(separateDomainsButton: true,
                                                passwordRestrictions: .default,
                                                summaryScreenVariant: .noSummaryScreen)
        return .init(appName: "Proton Authenticator",
                     clientApp: .other(named: "Proton Authenticator"),
                     apiService: apiService,
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
//            handle(logInData: logInData)
        }
    }
}
