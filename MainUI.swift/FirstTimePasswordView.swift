//
//  FirstTimePasswordView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/15/26.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct FirstTimePasswordView: View {

    @EnvironmentObject var authManager: AuthManager

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var isLoading = false

    var role: String

    var body: some View {
        VStack(spacing: 25) {

            Spacer()

            Image(systemName: "lock.shield.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)

            Text("First Time Login")
                .font(.title)
                .fontWeight(.bold)

            Text("You must create a new password to continue")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            SecureField("New Password", text: $newPassword)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            SecureField("Confirm Password", text: $confirmPassword)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            Button(action: updatePassword) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    Text("Update Password & Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .fontWeight(.semibold)
                }
            }
            .disabled(isLoading)

            Spacer()
        }
        .padding()
    }

    func updatePassword() {
        errorMessage = ""

        guard newPassword.count >= 8 else {
            errorMessage = "Password must be at least 8 characters."
            return
        }

        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        isLoading = true

        // ✅ Step 1 — Update password in Firebase Auth
        Auth.auth().currentUser?.updatePassword(to: newPassword) { error in
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
                return
            }

            // ✅ Step 2 — Update firstLogin to false in Firestore
            guard let uid = Auth.auth().currentUser?.uid else { return }

            Firestore.firestore()
                .collection("users")
                .document(uid)
                .updateData(["firstLogin": false]) { error in

                    if let error = error {
                        print("Firestore update error: \(error.localizedDescription)")
                    }

                    // ✅ Step 3 — Re-fetch user profile so AuthManager
                    // updates appUser and routes to the correct dashboard
                    DispatchQueue.main.async {
                        isLoading = false
                        authManager.fetchUserProfile(uid: uid)
                    }
                }
        }
    }
}




