//
//  DispatcherDashboardView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/16/26.
//


import SwiftUI

struct DispatcherDashboardView: View {

    var body: some View {
        NavigationView {
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
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // CREATE LOAD

                        NavigationLink(destination: CreateLoadView()) {
                            DashboardCard(
                                title: "Create Load", icon:
                                    "plus",
                                    color: .blue
                            )
                            
                        }
                        

                        
                        NavigationLink(destination: LoadBoardView()) {
                            DashboardCard(
                                title: "View Loads", icon: "list.bullet", color: .yellow
                            )
                            // card UI
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
                
                Spacer()
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

#Preview {
    DispatcherDashboardView()
        .environmentObject(AppState())
}


// Reusable Professional Card Component

