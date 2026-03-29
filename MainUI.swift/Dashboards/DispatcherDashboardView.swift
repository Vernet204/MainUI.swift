//
//  DispatcherDashboardView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/29/26.
//
import SwiftUI

struct DispatcherDashboardView: View {

    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // HEADER
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Dispatcher Dashboard")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Manage loads, drivers, and operations")
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    // QUICK ACTION CARDS
                    VStack(spacing: 20) {

                        // CREATE LOAD
                        NavigationLink(destination: CreateLoadView()) {
                            DashboardCard(
                                title: "Create Load",
                                icon: "plus",
                                color: .blue
                            )
                        }

                        // VIEW LOADS
                        NavigationLink(destination: LoadBoardView()) {
                            DashboardCard(
                                title: "View Loads",
                                icon: "list.bullet",
                                color: .yellow
                            )
                        }

                        // ASSIGN LOADS
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
            }
            // ✅ Toolbar on NavigationStack
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout") {
                        authManager.logout()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Dispatcher")
        }
    }
}

#Preview {
    DispatcherDashboardView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}

// Reusable Professional Card Component

