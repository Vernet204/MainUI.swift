import SwiftUI

struct OwnerDashboardView: View {

    @EnvironmentObject var authManager: AuthManager

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
            // ✅ .toolbar goes on NavigationStack, not on a NavigationLink
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout") {
                        authManager.logout()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Owner Dashboard")
        }
    }
}

#Preview {
    OwnerDashboardView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
