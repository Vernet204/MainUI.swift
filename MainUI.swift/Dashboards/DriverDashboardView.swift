//
//  DriverDashboardView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/29/26.
//

import SwiftUI

struct DriverDashboardView: View {

    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {

                // DVIR Inspection
                NavigationLink(destination: DVIRInspectionView()) {
                    DashboardButton(title: "DVIR Inspection", color: .green)
                }

                // Repair Report
                NavigationLink(destination: RepairReportView()) {
                    DashboardButton(title: "Repair Report", color: .orange)
                }

                // Accident Report
                NavigationLink(destination: AccidentReportView()) {
                    DashboardButton(title: "Report an Accident", color: .red)
                }

                // Assigned Loads
                NavigationLink(destination: Text("Assigned Loads Screen")) {
                    DashboardButton(title: "Assigned Loads", color: .blue)
                }

                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout") {
                        authManager.logout()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Driver Dashboard")
        }
    }
}

// ✅ DashboardButton defined here so it stays in scope
struct DashboardButton: View {
    var title: String
    var color: Color

    var body: some View {
        Text(title)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .foregroundColor(.white)
            .font(.headline)
            .cornerRadius(14)
    }
}

#Preview {
    DriverDashboardView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
