//
//  DriverDashboardView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/29/26.
//
import SwiftUI
import FirebaseFirestore

struct DriverDashboardView: View {

    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Assigned Loads
                    NavigationLink(destination: DriverLoadBoardView()) {
                        DashboardButton(title: "Assigned Loads", color: .blue)
                    }

                    // DVIR Inspection
                    NavigationLink(destination: DVIRInspectionView()) {
                        DashboardButton(title: "DVIR Inspection", color: .green)
                    }

                    // Repair Report
                    NavigationLink(destination: RepairReportView()) {
                        DashboardButton(title: "Repair Report", color: .orange)
                    }

                    // Accident Report
                    NavigationLink(destination: AccidentReportView()) {
                        DashboardButton(title: "Report an Accident", color: .red)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Driver Dashboard")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout") { authManager.logout() }
                        .foregroundColor(.red)
                }
            }
        }
    }
}

// MARK: - Driver Load Board
struct DriverLoadBoardView: View {

    @EnvironmentObject var authManager: AuthManager
    @State private var loads: [DriverLoad] = []
    @State private var selectedLoad: DriverLoad? = nil

    var body: some View {
        List {
            if loads.isEmpty {
                ContentUnavailableView(
                    "No Assigned Loads",
                    systemImage: "tray",
                    description: Text("Your dispatcher will assign loads here.")
                )
            } else {
                ForEach(loads) { load in
                    Button {
                        selectedLoad = load
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {

                            HStack {
                                Text("Load ID: \(load.loadID)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(load.status)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(statusColor(load.status).opacity(0.15))
                                    .foregroundColor(statusColor(load.status))
                                    .clipShape(Capsule())
                            }

                            Divider()

                            Label("Pickup: \(load.pickupLocation)", systemImage: "mappin.circle")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Label("Date & Time: \(load.pickupDate)", systemImage: "clock")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Label("Destination: \(load.deliveryLocation)", systemImage: "mappin.and.ellipse")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Label("Date & Time: \(load.dropoffDate)", systemImage: "clock.fill")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Assigned Loads")
        .onAppear { fetchAssignedLoads() }
        .sheet(item: $selectedLoad) { load in
            LoadAcceptDeclineView(load: load) { action in
                handleAction(action, for: load)
            }
        }
    }

    // MARK: - Accept / Decline Handler
    func handleAction(_ action: LoadAction, for load: DriverLoad) {
        let db = Firestore.firestore()

        switch action {
        case .accept:
            // Mark load as In Transit
            db.collection("loads").document(load.id).updateData([
                "status": "In Transit",
                "driverAccepted": true
            ])
            // Update local state
            if let index = loads.firstIndex(where: { $0.id == load.id }) {
                loads[index].status = "In Transit"
            }

        case .decline:
            // Send back to Unassigned so dispatcher can reassign
            db.collection("loads").document(load.id).updateData([
                "status": "Unassigned",
                "assignedDriver": "",
                "assignedVehicle": "",
                "driverAccepted": false,
                "declinedBy": authManager.appUser?.name ?? "Unknown"
            ])
            // Remove from driver's list
            loads.removeAll { $0.id == load.id }
        }

        selectedLoad = nil
    }

    // MARK: - Fetch Loads Assigned to This Driver
    func fetchAssignedLoads() {
        guard let driverName = authManager.appUser?.name else { return }

        Firestore.firestore()
            .collection("loads")
            .whereField("assignedDriver", isEqualTo: driverName)
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                loads = docs.map { doc in
                    let d = doc.data()
                    return DriverLoad(
                        id: doc.documentID,
                        loadID: d["loadID"] as? String ?? doc.documentID,
                        pickupLocation: d["pickupLocation"] as? String ?? "",
                        deliveryLocation: d["deliveryLocation"] as? String ?? "",
                        pickupDate: d["pickupDate"] as? String ?? "TBD",
                        dropoffDate: d["dropoffDate"] as? String ?? "TBD",
                        status: d["status"] as? String ?? "Assigned"
                    )
                }
            }
    }

    func statusColor(_ status: String) -> Color {
        switch status {
        case "Assigned": return .blue
        case "In Transit": return .purple
        case "Delivered": return .green
        default: return .gray
        }
    }
}

// MARK: - Accept / Decline Sheet
enum LoadAction {
    case accept, decline
}

struct LoadAcceptDeclineView: View {

    @Environment(\.dismiss) var dismiss
    let load: DriverLoad
    var onAction: (LoadAction) -> Void

    @State private var showDeclineConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("Load Details") {
                    DetailRow(label: "Load ID", value: load.loadID)
                    DetailRow(label: "Pickup", value: load.pickupLocation)
                    DetailRow(label: "Pickup Date & Time", value: load.pickupDate)
                    DetailRow(label: "Destination", value: load.deliveryLocation)
                    DetailRow(label: "Destination Date & Time", value: load.dropoffDate)
                }

                Section {
                    // ACCEPT
                    Button {
                        onAction(.accept)
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Accept Load")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }

                    // DECLINE
                    Button {
                        showDeclineConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("Decline Load")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .navigationTitle("Load \(load.loadID)")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                }
            }
            // Decline confirmation
            .confirmationDialog(
                "Decline this load?",
                isPresented: $showDeclineConfirm,
                titleVisibility: .visible
            ) {
                Button("Yes, Decline", role: .destructive) {
                    onAction(.decline)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This load will be sent back to the dispatcher for reassignment.")
            }
        }
    }
}

// MARK: - DriverLoad Model
struct DriverLoad: Identifiable {
    let id: String
    var loadID: String
    var pickupLocation: String
    var deliveryLocation: String
    var pickupDate: String
    var dropoffDate: String
    var status: String
}

// MARK: - DashboardButton
struct DashboardButton: View {
    var title: String
    var color: Color

    var body: some View {
        Text(title)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color)
            .foregroundColor(.white)
            .font(.headline)
            .cornerRadius(14)
    }
}

#Preview {
    DriverDashboardView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
