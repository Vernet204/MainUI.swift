import SwiftUI

struct OwnerDashboardView: View {

    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // 1. Manage Fleet
                    NavigationLink(destination: ManageFleetView()) {
                        DashboardCard(title: "Manage Fleet", icon: "truck.box.fill", color: .blue)
                    }

                    // 2. View Reports
                    NavigationLink(destination: ViewReport()) {
                        DashboardCard(title: "View Reports", icon: "doc.text.fill", color: .orange)
                    }
                    // load history
                    NavigationLink(destination: LoadHistoryView()) {
                        DashboardCard(
                            title: "Load History",
                            icon: "clock.arrow.circlepath",
                            color: .teal
                        )
                    }

                    // 3. Clientele
                    NavigationLink(destination: ClienteleView()) {
                        DashboardCard(title: "Clientele", icon: "building.2.fill", color: .green)
                    }
                    // maintence
                    NavigationLink(destination: MaintenanceView()) {
                        DashboardCard(
                            title: "Maintenance",
                            icon: "wrench.and.screwdriver.fill",
                            color: .indigo
                        )
                    }
                    
                    // Dispatch Role
                    NavigationLink(destination: DispatcherDashboardView()) {
                        DashboardCard(title: "Dispatch Role", icon: "antenna.radiowaves.left.and.right", color: .purple)
                    }

                    // Driver Role
                    NavigationLink(destination: DriverDashboardView()) {
                        DashboardCard(title: "Driver Role", icon: "person.fill", color: .red)
                    }
                }
                .padding()
            }
            .navigationTitle("Owner Dashboard")
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
    OwnerDashboardView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
