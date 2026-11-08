//
//  DispatcherDashboardView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/29/26.
//
import SwiftUI
import FirebaseFirestore

struct DispatcherDashboardView: View {

    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @StateObject private var packetService = LoadPacketService.shared

    // MARK: - Live Stats
    @State private var unassignedLoads = 0
    @State private var assignedLoads = 0
    @State private var inTransitLoads = 0
    @State private var declinedLoads = 0
    @State private var availableDrivers = 0
    @State private var totalDrivers = 0

    // MARK: - Alerts & Recent Activity
    @State private var alertItems: [DispatcherAlert] = []
    @State private var recentLoads: [RecentLoadItem] = []

    // MARK: - Listeners
    @State private var loadListener: ListenerRegistration? = nil
    @State private var driverListener: ListenerRegistration? = nil

    // MARK: - Sheets
    @State private var showFactoringPacket = false

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
                            DispatchStatCard(
                                value: "\(unassignedLoads)",
                                label: "Unassigned",
                                icon: "tray.fill",
                                color: unassignedLoads > 0 ? .orange : .gray
                            )
                            DispatchStatCard(
                                value: "\(assignedLoads)",
                                label: "Pending",
                                icon: "clock.fill",
                                color: .blue
                            )
                            DispatchStatCard(
                                value: "\(inTransitLoads)",
                                label: "In Transit",
                                icon: "truck.box.fill",
                                color: .purple
                            )
                            DispatchStatCard(
                                value: "\(declinedLoads)",
                                label: "Declined",
                                icon: "xmark.circle.fill",
                                color: declinedLoads > 0 ? .red : .gray
                            )
                            DispatchStatCard(
                                value: "\(availableDrivers)",
                                label: "Available",
                                icon: "person.fill.checkmark",
                                color: .green
                            )
                            DispatchStatCard(
                                value: "\(totalDrivers)",
                                label: "Total Drivers",
                                icon: "person.3.fill",
                                color: .teal
                            )
                        }
                        .padding(.horizontal)
                    }

                    // MARK: - BOL Tasks — action required
                    if !packetService.bolTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("BOL Action Required (\(packetService.bolTasks.count))")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding(.horizontal)

                            VStack(spacing: 8) {
                                ForEach(packetService.bolTasks) { task in
                                    BOLTaskRow(task: task) {
                                        packetService.fetchBOLTasks()
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // MARK: - Dispatcher Alerts
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
                                    DispatcherAlertRow(alert: alert)
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

                    // MARK: - Navigation cards
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tools")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 12) {
                            NavigationLink(destination: CreateLoadView()) {
                                DashboardCard(
                                    title: "Create Load",
                                    icon: "plus.circle.fill",
                                    color: .blue
                                )
                            }

                            NavigationLink(destination: DispatcherLoadBoardView()) {
                                DashboardCard(
                                    title: "Load Board",
                                    icon: "list.bullet.rectangle",
                                    color: .blue
                                )
                            }

                            NavigationLink(destination: DriverScheduleView()) {
                                DashboardCard(
                                    title: "Driver Schedule",
                                    icon: "calendar.badge.clock",
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

                            Button {
                                showFactoringPacket = true
                            } label: {
                                DashboardCard(
                                    title: "Factoring Packet",
                                    icon: "doc.on.doc.fill",
                                    color: .indigo
                                )
                            }
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Dispatcher")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout") { authManager.logout() }
                        .foregroundColor(.red)
                }
            }
            .onAppear {
                packetService.fetchBOLTasks()
                startListeners()
            }
            .onDisappear { stopListeners() }
            .refreshable { refreshData() }
            .sheet(isPresented: $showFactoringPacket) {
                FactoringPacketView()
                    .environmentObject(authManager)
            }
        }
    }

    // MARK: - Listeners
    func startListeners() {
        listenToLoads()
        listenToDrivers()
    }

    func stopListeners() {
        loadListener?.remove()
        driverListener?.remove()
        loadListener = nil
        driverListener = nil
    }

    func refreshData() {
        stopListeners()
        startListeners()
        packetService.fetchBOLTasks()
    }

    // MARK: - Load Listener
    func listenToLoads() {
        loadListener = Firestore.firestore()
            .collection("loads")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }

                var unassigned = 0
                var assigned = 0
                var inTransit = 0
                var declined = 0
                var alerts: [DispatcherAlert] = []
                var recent: [RecentLoadItem] = []

                for doc in docs {
                    let d = doc.data()
                    let status = d["status"] as? String ?? ""
                    let loadID = d["loadID"] as? String ?? doc.documentID
                    let pickup = d["pickupLocation"] as? String ?? ""
                    let delivery = d["deliveryLocation"] as? String ?? ""
                    let driver = d["assignedDriver"] as? String ?? ""
                    let createdAt = (d["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    let pickupDT = (d["pickupDateTime"] as? Timestamp)?.dateValue()

                    switch status {
                    case "Unassigned":
                        unassigned += 1
                        //  Alert if pickup is within 24 hours and still unassigned
                        if let pt = pickupDT, pt.timeIntervalSinceNow < 86400 && pt > Date() {
                            alerts.append(DispatcherAlert(
                                id: doc.documentID,
                                title: "Urgent: Unassigned Load",
                                message: "Load \(loadID) picks up \(pt.formatted(date: .abbreviated, time: .shortened)) with no driver.",
                                color: .red,
                                icon: "exclamationmark.triangle.fill"
                            ))
                        }
                    case "Assigned", "Accepted":
                        assigned += 1
                    case "In Transit":
                        inTransit += 1
                    case "Declined":
                        declined += 1
                        alerts.append(DispatcherAlert(
                            id: doc.documentID + "_declined",
                            title: "Load Declined",
                            message: "Load \(loadID) was declined and needs a new driver.",
                            color: .red,
                            icon: "xmark.circle.fill"
                        ))
                    default:
                        break
                    }

                    if status != "Delivered" {
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
                }

                DispatchQueue.main.async {
                    unassignedLoads = unassigned
                    assignedLoads   = assigned
                    inTransitLoads  = inTransit
                    declinedLoads   = declined
                    alertItems      = alerts
                    recentLoads     = recent.sorted { $0.createdAt > $1.createdAt }
                }
            }
    }

    // MARK: - Driver Listener
    func listenToDrivers() {
        driverListener = Firestore.firestore()
            .collection("users")
            .whereField("role", isEqualTo: "Driver")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let total = docs.count

                //  Available = drivers not currently assigned/accepted/in transit
                Firestore.firestore()
                    .collection("loads")
                    .whereField("status", in: ["Assigned", "Accepted", "In Transit"])
                    .getDocuments { loadSnap, _ in
                        let busyDrivers = Set(
                            (loadSnap?.documents ?? [])
                                .compactMap { $0.data()["assignedDriver"] as? String }
                                .filter { !$0.isEmpty }
                        )

                        DispatchQueue.main.async {
                            totalDrivers     = total
                            availableDrivers = max(0, total - busyDrivers.count)
                        }
                    }
            }
    }
}

// MARK: - Dispatch Stat Card
struct DispatchStatCard: View {
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

// MARK: - Dispatcher Alert Row
struct DispatcherAlertRow: View {
    let alert: DispatcherAlert

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

// MARK: - Models
struct DispatcherAlert: Identifiable {
    let id: String
    let title: String
    let message: String
    let color: Color
    let icon: String
}

#Preview {
    DispatcherDashboardView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
