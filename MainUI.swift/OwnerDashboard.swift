struct OwnerDashboard: View {
    var body: some View {
        VStack(spacing: 20) {
            
            Text("Fleet Owner Dashboard")
                .font(.title)
                .fontWeight(.bold)
            
            NavigationLink(destination: CreateEmployeeView()) {
                DashboardCard(
                    title: "Create Employee Account",
                    subtitle: "Assign roles to employees",
                    icon: "person.badge.plus",
                    color: .orange
                )
            }
            
            DashboardCard(
                title: "Manage Fleet",
                subtitle: " ",
                icon: "truck.box",
                color: .blue
            )
            DashboardCard(
                title: "View Reports",
                subtitle: " ",
                icon: "chart.bar",
                color: .green
            )
            
            Spacer()
        }
        .padding()
    }
}