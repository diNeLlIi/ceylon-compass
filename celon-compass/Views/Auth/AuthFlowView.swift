//
//  AuthFlowView.swift
//  celon-compass
//
//  Container view that routes between auth screens based on AuthViewModel.screen.
//

import SwiftUI

struct AuthFlowView: View {
    @State private var model = AuthViewModel()

    var body: some View {
        NavigationStack {
            Group {
                switch model.screen {
                case .createAccount:
                    CreateAccountView(model: model)
                case .signIn:
                    SignInView(model: model)
                case .forgotPassword:
                    ForgotPasswordView(model: model)
                case .checkEmail(let email):
                    CheckEmailView(model: model, email: email)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.screen)
        }
    }
}
