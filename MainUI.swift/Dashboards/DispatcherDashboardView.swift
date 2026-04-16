//
//  DispatcherDashboardView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/29/26.
//
import SwiftUI
import FirebaseFirestore

struct DispatcherDashboardView: View {

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    NavigationLink(destination: DispatcherLoadBoardView()) {
                        DashboardCard(
                            title: "Load Board",
                            icon: "list.bullet.rectangle",
                            color: .blue
                        )
                    }

                    NavigationLink(destination: AssignLoadView()) {
                        DashboardCard(
                            title: "Assign Loads",
                            icon: "person.crop.circle.badge.checkmark",
                            color: .green
                        )
                    }

                    NavigationLink(destination: DriverScheduleView()) {
                        DashboardCard(
                            title: "Driver Schedule",
                            icon: "calendar.badge.clock",
                            color: .purple
                        )
                    }
                    
                    // load history
                    NavigationLink(destination: LoadHistoryView()) {
                        DashboardCard(
                            title: "Load History",
                            icon: "clock.arrow.circlepath",
                            color: .teal
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
