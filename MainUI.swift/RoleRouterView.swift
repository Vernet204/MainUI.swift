//
//  RoleRouterView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/15/26.
//


import SwiftUI

struct RoleRouterView: View {
    var role: String
    
    var body: some View {
        switch role {
        case "Owner":
            OwnerDashboard()
        case "Dispatcher":
            DispatcherDashboard()
        case "Driver":
            DriverDashboardView()
        default:
            Text("Access Denied")
                .font(.title)
        }
    }

}

