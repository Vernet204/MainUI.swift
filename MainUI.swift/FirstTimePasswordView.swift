//
//  FirstTimePasswordView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/15/26.
//


import SwiftUI

struct FirstTimePasswordView: View {
    
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    @State private var passwordUpdated = false
    
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
                Text("Update Password & Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding()
    }
    
    func updatePassword() {
        if newPassword.count < 8 {
            errorMessage = "Password must be at least 8 characters."
        } else if newPassword != confirmPassword {
            errorMessage = "Passwords do not match."
        } else {
            // 🔹 Backend API call goes here later
            passwordUpdated = true        }
    }

}


