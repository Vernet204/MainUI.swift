//
//  ContentView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/29/26.
//
import SwiftUI

struct ContentView: View {

    @StateObject private var authManager = AuthManager()
    @StateObject private var appState = AppState()

    var body: some View {
        Group {
            if authManager.isLoading {
                // Splash / loading screen while Firebase checks auth state
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.gray)
                }

            } else if let user = authManager.appUser {
                // User is logged in — route by role
                if user.isFirstLogin {
                    FirstTimePasswordView(role: user.role)
                        .environmentObject(authManager)
                } else {
                    RoleRouterView(role: user.role)
                        .environmentObject(authManager)
                        .environmentObject(appState)
                }

            } else {
                // Not logged in
                NavigationStack {
                    LoginView()
                        .environmentObject(authManager)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
