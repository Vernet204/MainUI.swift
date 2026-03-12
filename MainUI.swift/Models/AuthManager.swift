//
//  AuthManager.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/15/26.
//


import Foundation

class AuthManager: ObservableObject {
    
    // Simulated database (later replace with Firebase/API)
    @Published var users: [AppUser] = []
    
    
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

    func registerOwner(name: String, email: String, password: String) {

        let newUser = AppUser(
            id: UUID(),
            name: name,
            email: email,
            password: password,
            role: "",
            isFirstLogin: true
        )

            users.append(newUser)
        }
    }
    


