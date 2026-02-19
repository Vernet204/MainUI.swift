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
                            Text("Create Load")
                        }
                        

                        
                        NavigationLink(destination: LoadBoardView()) {
                            DashboardCard(
                                title: "View Loads", subtitle: "See all current loads", icon: "list.bullet", color: .yellow
                            )
                            // card UI
                        }

                        
                        // ASSIGN LOADS
                        NavigationLink(destination: AssignLoadView()) {
                            DashboardCard(
                                title: "Assign Loads",
                                subtitle: "Assign loads to drivers",
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
struct DashboardCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 15) {
            
            // ICON
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.15))
                    .frame(width: 55, height: 55)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
            }
            
            // TEXT
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // ARROW
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 3)
    }
}
