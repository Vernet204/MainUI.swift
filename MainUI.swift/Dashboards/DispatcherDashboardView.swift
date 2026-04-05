//
//  DispatcherDashboardView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/29/26.
//
import SwiftUI

struct DispatcherDashboardView: View {

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Load Board
                    NavigationLink(destination: DispatcherLoadBoardView()) {
                        DashboardCard(
                            title: "Load Board",
                            icon: "list.bullet.rectangle",
                            color: .blue
                        )
                    }

                    // Assign Loads
                    NavigationLink(destination: AssignLoadView()) {
                        DashboardCard(
                            title: "Assign Loads",
                            icon: "person.crop.circle.badge.checkmark",
                            color: .green
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Dispatcher")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout") { authManager.logout() }
                        .foregroundColor(.red)
                }
            }
        }
    }
}

#Preview {
    DispatcherDashboardView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
