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
                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    ProgressView("Loading...")
                }
            } else if let user = authManager.appUser {
                if user.isFirstLogin {
                    NavigationStack {
                        FirstTimePasswordView(role: user.role)
                    }
                    .environmentObject(authManager)
                } else {
                    RoleRouterView(role: user.role)
                        .environmentObject(authManager)
                        .environmentObject(appState)
                        .onAppear {
                            appState.startListeningToReports()
                            // ✅ Request notification permission and save FCM token
                            NotificationManager.shared.requestPermissionAndRegister()
                            NotificationManager.shared.saveFCMToken()
                        }
                        .onDisappear {
                            appState.stopAllListeners()
                        }
                }
            } else {
                NavigationStack {
                    LoginView()
                }
                .environmentObject(authManager)
            }
        }
    }
}

#Preview {
    ContentView()
}
