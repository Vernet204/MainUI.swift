//
//  RoleRouterView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/29/26.
//


import SwiftUI

struct RoleRouterView: View {
    var role: String

    var body: some View {
        // Use lowercased() so "Owner", "owner", "OWNER" all work
        switch role.lowercased() {
        case "owner":
            OwnerDashboardView()
        case "dispatcher":
            DispatcherDashboardView()
        case "driver":
            DriverDashboardView()
        default:
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)

                Text("Role Not Found")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Contact your administrator.")
                    .foregroundColor(.gray)
            }
        }
    }
}

