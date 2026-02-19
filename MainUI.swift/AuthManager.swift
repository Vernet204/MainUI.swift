//
//  AuthManager.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/15/26.
//


import Foundation

class AuthManager: ObservableObject {
    
    // Simulated database (later replace with Firebase/API)
    @Published var users: [AppUser] = [
        AppUser(email: "owner@test.com", password: "12345678", role: "Owner", isFirstLogin: false),
        AppUser(email: "dispatch@test.com", password: "12345678", role: "Dispatcher", isFirstLogin: false),
        AppUser(email: "driver@test.com", password: "temp1234", role: "Driver", isFirstLogin: true)
    ]
    
    func login(email: String, password: String) -> AppUser? {
        return users.first { user in
            user.email.lowercased() == email.lowercased() &&
            user.password == password
        }
    }
    
    func updatePassword(for email: String, newPassword: String) {
        if let index = users.firstIndex(where: { $0.email == email }) {
            users[index].password = newPassword
            users[index].isFirstLogin = false
        }
    }

}
