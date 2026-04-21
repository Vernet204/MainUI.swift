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
        // ✅ Always lowercased to handle any capitalization from Firestore
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
                Text("Access Denied")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Role '\(role)' is not recognized.\nContact your administrator.")
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
}
