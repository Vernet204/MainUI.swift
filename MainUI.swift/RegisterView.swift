import SwiftUI

struct RegisterView: View {

    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var ownerName = ""
    @State private var companyName = ""
    @State private var email = ""
    @State private var password = ""

    @State private var errorMessage = ""
    @State private var didRegister = false

    var body: some View {
        VStack(spacing: 16) {

            Text("Register Company")
                .font(.title)
                .fontWeight(.bold)

            Text("Fleet Owner only")
                .foregroundColor(.gray)

            TextField("Owner Full Name", text: $ownerName)
                .textInputAutocapitalization(.words)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            TextField("Company Name", text: $companyName)
                .textInputAutocapitalization(.words)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            TextField("Owner Email", text: $email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            SecureField("Password (8+ characters)", text: $password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button("Register") {
                registerOwner()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)

            Button("Back to Login") {
                dismiss()
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding()
        .alert("Registration Complete", isPresented: $didRegister) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your owner account was created. (Email confirmation can be added later.)")
        }
    }

    private func registerOwner() {
        errorMessage = ""

        guard !ownerName.isEmpty else { errorMessage = "Enter owner name."; return }
        guard !companyName.isEmpty else { errorMessage = "Enter company name."; return }
        guard email.contains("@") else { errorMessage = "Enter a valid email."; return }
        guard password.count >= 8 else { errorMessage = "Password must be at least 8 characters."; return }

        // Prevent duplicate email
        if authManager.users.contains(where: { $0.email.lowercased() == email.lowercased() }) {
            errorMessage = "That email is already registered."
            return
        }

        // ✅ Create owner account (companyName stored later when you add Company model)
        authManager.registerOwner(name: ownerName, email: email, password: password)

        // ✅ Placeholder for “System sends confirmation email”
        // Later: call backend API here to send verification email.

        didRegister = true
    }
}