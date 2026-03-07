//
//  AppUser.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/15/26.
//


import Foundation

struct AppUser: Identifiable {
    let id: UUID
    var name: String
    var email: String
    var password: String
    var role: String
    var isFirstLogin: Bool
}
