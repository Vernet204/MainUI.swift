//
//  LoginView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/29/26.
//
import SwiftUI
import FirebaseAuth

struct LoginView: View {

    @EnvironmentObject var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = "Login failed. Check credentials."
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 25) {

            Spacer()

            Image(systemName: "truck.box.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

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
                .keyboardType(.emailAddress)

            SecureField("Password", text: $password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button {
                loginUser()
            } label: {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                } else {
                    Text("Login")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .fontWeight(.semibold)
                }
            }
            .disabled(isLoading)
            .padding(.top, 10)

            Spacer()
        }
        .padding()
    }

    // MARK: - Firebase Login
    func loginUser() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter your email and password."
            showError = true
            return
        }

        isLoading = true
        showError = false

        // ✅ Firebase Auth — AuthManager handles routing via listener
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error {
                    print("❌ Login error: \(error.localizedDescription)")
                    errorMessage = "Login failed. Check your credentials."
                    showError = true
                }
                // ✅ On success AuthManager's listener fires automatically
                // and ContentView re-routes based on appUser.role
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
