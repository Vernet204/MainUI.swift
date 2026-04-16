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
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.gray)
                }

            } else if let user = authManager.appUser {

                if user.isFirstLogin {
                    FirstTimePasswordView(role: user.role)
                        .environmentObject(authManager)
                } else {
                    RoleRouterView(role: user.role)
                        .environmentObject(authManager)
                        .environmentObject(appState)
                        // ✅ Start listeners when user is logged in
                        .onAppear {
                            appState.startListeningToLoads()
                            appState.startListeningToReports()
                        }
                }

            } else {
                NavigationStack {
                    LoginView()
                        .environmentObject(authManager)
                        // ✅ Stop listeners when user logs out
                        .onAppear {
                            appState.stopAllListeners()
                        }
                }
            }
        }
    }
}
