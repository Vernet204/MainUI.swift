//
//  LoginView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/29/26.
//
import SwiftUI

struct LoginView: View {

    @EnvironmentObject var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage = ""
    @State private var isLoggingIn = false

    var body: some View {
        VStack(spacing: 25) {

            Spacer()

            Text("Freight Carrier Assist")
                .font(.title)
                .fontWeight(.bold)

            Text("Company Login Portal")
                .foregroundColor(.gray)

            TextField("Email Address", text: $email)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Password", text: $password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: attemptLogin) {
                if isLoggingIn {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .disabled(isLoggingIn)

            Spacer()
        }
        .padding()
    }

    // MARK: - Login Action
    private func attemptLogin() {
        errorMessage = ""
        isLoggingIn = true

        authManager.login(email: email, password: password) { error in
            isLoggingIn = false
            if let error = error {
                errorMessage = error
            }
            // On success: ContentView reacts to authManager.appUser automatically
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
