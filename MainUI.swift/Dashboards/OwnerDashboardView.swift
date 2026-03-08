//
//  OwnerDashboardView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/7/26.
//


import SwiftUI

struct OwnerDashboardView: View {
    
    var body: some View {
        
        NavigationStack {
            
            ScrollView {
                
                VStack(spacing: 20) {
                    
                    Text("Owner Dashboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    
                    // Fleet Management
                    
                    NavigationLink(destination: ManageFleetView()) {
                        DashboardCard(
                            title: "Manage Fleet",
                            icon: "truck.box.fill",
                            color: .blue
                        )
                    }
                    
                    
                    
                    
                    // Employees
                    
                    NavigationLink(destination: EmployeeManagementView()) {
                        DashboardCard(
                            title: "Employees",
                            icon: "person.3.fill",
                            color: .purple
                        )
                    }
                    
                    
                    // Reports
                    
                    NavigationLink(destination: ViewReport()) {
                        DashboardCard(
                            title: "Reports",
                            icon: "doc.text.fill",
                            color: .orange
                        )
                    }
                    
                    
                    // Performance
                    
                    NavigationLink(destination: PerformanceView()) {
                        DashboardCard(
                            title: "Performance",
                            icon: "chart.bar.fill",
                            color: .red
                        )
                    }
                    
                }
                .padding()
            }
        }
    }
}
#Preview {
    OwnerDashboardView()
}
