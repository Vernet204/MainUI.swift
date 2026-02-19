//
//  DriverDashboardView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/15/26.
//


import SwiftUI

struct DriverDashboardView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 25) {
                
                Text("Driver Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Vehicle Inspection Button
                NavigationLink(destination: DVIRInspectionView()) {
                    DashboardButton(title: "DVIR Inspection", color: .green)
                }
                
                // Vehicle Repair Report Button
                NavigationLink(destination: RepairReportView()) {
                    DashboardButton(title: "Repair Report", color: .orange)
                }
                
                // Accident Report Button
                NavigationLink(destination: AccidentReportView()) {
                    DashboardButton(title: "Report an Accident", color: .red)
                }

                
                // Future: Loads
                NavigationLink(destination: Text("Assigned Loads Screen")) {
                    DashboardButton(title: "Assigned Loads", color: .blue)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

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
        .environmentObject(AppState())
}

