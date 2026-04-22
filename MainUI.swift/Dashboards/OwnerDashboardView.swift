import SwiftUI
import FirebaseFirestore
 
struct OwnerDashboardView: View {
 
    @EnvironmentObject var authManager: AuthManager
 
    // MARK: - Live Stats
    @State private var activeLoads = 0
    @State private var deliveredToday = 0
    @State private var driversOnRoad = 0
    @State private var vehiclesInMaintenance = 0
    @State private var openReports = 0
    @State private var declinedLoads = 0
 
    // MARK: - Alerts — stored separately to prevent race condition overwrites
    @State private var loadAlerts: [OwnerAlert] = []
    @State private var vehicleAlerts: [OwnerAlert] = []
    @State private var reportAlerts: [OwnerAlert] = []
 
    // MARK: - Computed: merge all alerts safely
    var alertItems: [OwnerAlert] {
        loadAlerts + vehicleAlerts + reportAlerts
    }
 
    // MARK: - Recent Activity
    @State private var recentLoads: [RecentLoadItem] = []
 
    // MARK: - Revenue
    @State private var weeklyRevenue: Double = 0
    @State private var monthlyRevenue: Double = 0
    @State private var topDriver = ""
 
    // MARK: - Listeners
    @State private var loadListener: ListenerRegistration? = nil
    @State private var vehicleListener: ListenerRegistration? = nil
    @State private var reportListener: ListenerRegistration? = nil
 
    @State private var isLoading = true
 
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
 
                    // MARK: - Live Stats Grid
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Live Overview")
                            .font(.headline)
                            .padding(.horizontal)
 
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            OwnerStatCard(
                                value: "\(activeLoads)",
                                label: "Active Loads",
                                icon: "shippingbox.fill",
                                color: .blue
                            )
                            OwnerStatCard(
                                value: "\(deliveredToday)",
                                label: "Delivered Today",
                                icon: "checkmark.seal.fill",
                                color: .green
                            )
                            OwnerStatCard(
                                value: "\(driversOnRoad)",
                                label: "On The Road",
                                icon: "steeringwheel",
                                color: .purple
                            )
                            OwnerStatCard(
                                value: "\(vehiclesInMaintenance)",
                                label: "In Maintenance",
                                icon: "wrench.fill",
                                color: vehiclesInMaintenance > 0 ? .orange : .gray
                            )
                            OwnerStatCard(
                                value: "\(openReports)",
                                label: "Open Reports",
                                icon: "doc.text.fill",
                                color: openReports > 0 ? .red : .gray
                            )
                            OwnerStatCard(
                                value: "\(declinedLoads)",
                                label: "Declined",
                                icon: "xmark.circle.fill",
                                color: declinedLoads > 0 ? .red : .gray
                            )
                        }
                        .padding(.horizontal)
                    }
 
                    // MARK: - Revenue Summary
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Revenue")
                            .font(.headline)
                            .padding(.horizontal)
 
                        HStack(spacing: 12) {
                            RevenueCard(
                                title: "This Week",
                                amount: weeklyRevenue,
                                icon: "calendar",
                                color: .green
                            )
                            RevenueCard(
                                title: "This Month",
                                amount: monthlyRevenue,
                                icon: "calendar.badge.clock",
                                color: .blue
                            )
                        }
                        .padding(.horizontal)
 
                        if !topDriver.isEmpty {
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(.yellow)
                                Text("Top Driver: \(topDriver)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal)
                        }
                    }
 
                    // MARK: - Alerts Section
                    if !alertItems.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Needs Attention (\(alertItems.count))")
                                    .font(.headline)
                            }
                            .padding(.horizontal)
 
                            VStack(spacing: 8) {
                                ForEach(alertItems) { alert in
                                    AlertRow(alert: alert)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
 
                    // MARK: - Recent Loads
                    if !recentLoads.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent Loads")
                                .font(.headline)
                                .padding(.horizontal)
 
                            VStack(spacing: 8) {
                                ForEach(recentLoads.prefix(5)) { load in
                                    RecentLoadRow(load: load)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
 
                    // MARK: - Navigation Cards
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Management")
                            .font(.headline)
                            .padding(.horizontal)
 
                        VStack(spacing: 12) {
                            NavigationLink(destination: ManageFleetView()) {
                                DashboardCard(
                                    title: "Manage Fleet",
                                    icon: "truck.box.fill",
                                    color: .blue
                                )
                            }
                            NavigationLink(destination: DispatcherDashboardView()) {
                                DashboardCard(
                                    title: "Dispatch Console",
                                    icon: "antenna.radiowaves.left.and.right",
                                    color: .purple
                                )
                            }
                            NavigationLink(destination: LoadHistoryView()) {
                                DashboardCard(
                                    title: "Load History",
                                    icon: "clock.arrow.circlepath",
                                    color: .teal
                                )
                            }
                            NavigationLink(destination: ViewReport()) {
                                DashboardCard(
                                    title: "Reports",
                                    icon: "doc.text.fill",
                                    color: .orange
                                )
                            }
                            NavigationLink(destination: MaintenanceView()) {
                                DashboardCard(
                                    title: "Maintenance",
                                    icon: "wrench.and.screwdriver.fill",
                                    color: .indigo
                                )
                            }
                            NavigationLink(destination: ClienteleView()) {
                                DashboardCard(
                                    title: "Clientele",
                                    icon: "building.2.fill",
                                    color: .green
                                )
                            }
                            NavigationLink(destination: DriverDashboardView()) {
                                DashboardCard(
                                    title: "Driver View",
                                    icon: "person.fill",
                                    color: .red
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
 
                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Owner Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout") {
                        authManager.logout()
                    }
                    .foregroundColor(.red)
                }
            }
            .onAppear { startListeners() }
            .onDisappear { stopListeners() }
            .refreshable { refreshData() }
        }
    }
 
    // MARK: - Listeners
    func startListeners() {
        isLoading = true
        listenToLoads()
        listenToVehicles()
        listenToReports()
    }
 
    func stopListeners() {
        loadListener?.remove()
        vehicleListener?.remove()
        reportListener?.remove()
        loadListener = nil
        vehicleListener = nil
        reportListener = nil
    }
 
    func refreshData() {
        stopListeners()
        startListeners()
    }
 
    // MARK: - Load Listener
    func listenToLoads() {
        loadListener = Firestore.firestore()
            .collection("loads")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
 
                var active = 0
                var delivered = 0
                var onRoad = 0
                var declined = 0
                var weekly: Double = 0
                var monthly: Double = 0
                var driverCounts: [String: Int] = [:]
                var recent: [RecentLoadItem] = []
                var alerts: [OwnerAlert] = []
 
                let calendar = Calendar.current
                let now = Date()
                let startOfDay = calendar.startOfDay(for: now)
                let startOfWeek = calendar.date(
                    from: calendar.dateComponents(
                        [.yearForWeekOfYear, .weekOfYear], from: now
                    )
                ) ?? now
                let startOfMonth = calendar.date(
                    from: calendar.dateComponents([.year, .month], from: now)
                ) ?? now
 
                for doc in docs {
                    let d = doc.data()
                    let status       = d["status"] as? String ?? ""
                    let driver       = d["assignedDriver"] as? String ?? ""
                    let loadID       = d["loadID"] as? String ?? doc.documentID
                    let pickup       = d["pickupLocation"] as? String ?? ""
                    let delivery     = d["deliveryLocation"] as? String ?? ""
                    let rateStr      = d["rate"] as? String ?? "0"
                    let rate         = Double(rateStr) ?? 0
                    let createdAt    = (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let deliveredAt  = (d["deliveredAt"] as? Timestamp)?.dateValue()
 
                    switch status {
                    case "Assigned", "Accepted":
                        active += 1
                    case "In Transit":
                        active += 1
                        onRoad += 1
                    case "Delivered":
                        if let da = deliveredAt, da >= startOfDay {
                            delivered += 1
                        }
                        if let da = deliveredAt {
                            if da >= startOfWeek  { weekly  += rate }
                            if da >= startOfMonth { monthly += rate }
                        }
                        if !driver.isEmpty {
                            driverCounts[driver, default: 0] += 1
                        }
                    case "Declined":
                        declined += 1
                        alerts.append(OwnerAlert(
                            id: doc.documentID,
                            type: .declinedLoad,
                            title: "Declined Load",
                            message: "Load \(loadID) was declined and needs reassignment.",
                            color: .red,
                            icon: "xmark.circle.fill"
                        ))
                    default:
                        break
                    }
 
                    recent.append(RecentLoadItem(
                        id: doc.documentID,
                        loadID: loadID,
                        pickup: pickup,
                        delivery: delivery,
                        status: status,
                        driver: driver,
                        createdAt: createdAt
                    ))
                }
 
                let top = driverCounts.max(by: { $0.value < $1.value })?.key ?? ""
 
                DispatchQueue.main.async {
                    activeLoads    = active
                    deliveredToday = delivered
                    driversOnRoad  = onRoad
                    declinedLoads  = declined
                    weeklyRevenue  = weekly
                    monthlyRevenue = monthly
                    topDriver      = top
                    recentLoads    = recent.sorted { $0.createdAt > $1.createdAt }
                    // ✅ Write only to loadAlerts — other alert arrays untouched
                    loadAlerts     = alerts
                    isLoading      = false
                }
            }
    }
 
    // MARK: - Vehicle Listener
    func listenToVehicles() {
        vehicleListener = Firestore.firestore()
            .collection("vehicles")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
 
                var maintenance = 0
                var alerts: [OwnerAlert] = []
 
                for doc in docs {
                    let d          = doc.data()
                    let status     = d["status"] as? String ?? ""
                    let unit       = d["unitNumber"] as? String ?? ""
                    let inspStatus = d["inspectionStatus"] as? String ?? ""
 
                    if status == "In Maintenance" {
                        maintenance += 1
                        alerts.append(OwnerAlert(
                            id: doc.documentID,
                            type: .vehicleInMaintenance,
                            title: "Vehicle In Maintenance",
                            message: "Unit \(unit) — \(inspStatus.isEmpty ? "Needs attention" : inspStatus)",
                            color: .orange,
                            icon: "wrench.fill"
                        ))
                    }
                }
 
                DispatchQueue.main.async {
                    vehiclesInMaintenance = maintenance
                    // ✅ Write only to vehicleAlerts — other alert arrays untouched
                    vehicleAlerts = alerts
                }
            }
    }
 
    // MARK: - Report Listener
    func listenToReports() {
        reportListener = Firestore.firestore()
            .collection("reports")
            .whereField("status", isEqualTo: "Open")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
 
                var open = 0
                var alerts: [OwnerAlert] = []
 
                for doc in docs {
                    let d         = doc.data()
                    let type      = (d["type"] as? String ?? "").capitalized
                    let driver    = d["driverName"] as? String
                        ?? d["driver"] as? String ?? "Unknown"
                    let reportNum = d["reportNumber"] as? String ?? ""
                    open += 1
                    alerts.append(OwnerAlert(
                        id: doc.documentID,
                        type: .openReport,
                        title: "Open \(type) Report",
                        message: "\(reportNum.isEmpty ? "Report" : reportNum) from \(driver) needs review.",
                        color: .red,
                        icon: "doc.text.fill"
                    ))
                }
 
                DispatchQueue.main.async {
                    openReports  = open
                    // ✅ Write only to reportAlerts — other alert arrays untouched
                    reportAlerts = alerts
                }
            }
    }
}
 
// MARK: - Owner Stat Card
struct OwnerStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
 
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}
 
// MARK: - Revenue Card
struct RevenueCard: View {
    let title: String
    let amount: Double
    let icon: String
    let color: Color
 
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 36)
 
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("$\(String(format: "%.0f", amount))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
 
            Spacer()
        }
        .padding()
        .background(color.opacity(0.08))
        .cornerRadius(12)
        .frame(maxWidth: .infinity)
    }
}
 
// MARK: - Alert Row
struct AlertRow: View {
    let alert: OwnerAlert
 
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: alert.icon)
                .foregroundColor(alert.color)
                .font(.title3)
                .frame(width: 30)
 
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(alert.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
 
            Spacer()
        }
        .padding()
        .background(alert.color.opacity(0.07))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(alert.color.opacity(0.2), lineWidth: 1)
        )
    }
}
 
// MARK: - Recent Load Row
struct RecentLoadRow: View {
    let load: RecentLoadItem
 
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor(load.status))
                .frame(width: 10, height: 10)
 
            VStack(alignment: .leading, spacing: 2) {
                Text("Load \(load.loadID)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(load.pickup) → \(load.delivery)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
 
            Spacer()
 
            VStack(alignment: .trailing, spacing: 2) {
                Text(load.status)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(statusColor(load.status))
                if !load.driver.isEmpty {
                    Text(load.driver)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
 
    func statusColor(_ status: String) -> Color {
        switch status {
        case "Unassigned": return .orange
        case "Assigned":   return .blue
        case "Accepted":   return .green
        case "Declined":   return .red
        case "In Transit": return .purple
        case "Delivered":  return .green
        default:           return .gray
        }
    }
}
 
// MARK: - Models
struct OwnerAlert: Identifiable {
    let id: String
    let type: OwnerAlertType
    let title: String
    let message: String
    let color: Color
    let icon: String
}
 
enum OwnerAlertType {
    case declinedLoad
    case vehicleInMaintenance
    case openReport
}
 
struct RecentLoadItem: Identifiable {
    let id: String
    var loadID: String
    var pickup: String
    var delivery: String
    var status: String
    var driver: String
    var createdAt: Date
}
 
#Preview {
    OwnerDashboardView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
