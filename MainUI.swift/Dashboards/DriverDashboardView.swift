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
// MARK: - Driver Load Board
struct DriverLoadBoardView: View {

    @EnvironmentObject var authManager: AuthManager
    @State private var loads: [DriverLoad] = []
    @State private var selectedLoad: DriverLoad? = nil
    @State private var isLoading = true
    @State private var listener: ListenerRegistration? = nil

    // ✅ Computed property for active loads only
    var activeLoads: [DriverLoad] {
        loads.filter { $0.status.lowercased() != "delivered" }
    }

    var body: some View {
        List {
            if isLoading {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading your loads...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding()

            } else if activeLoads.isEmpty {
                ContentUnavailableView(
                    "No Active Loads",
                    systemImage: "tray",
                    description: Text("You have no active loads. Your dispatcher will assign loads here.")
                )

            } else {
                ForEach(activeLoads) { load in
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

                            Label(
                                "Pickup: \(load.pickupLocation)",
                                systemImage: "mappin.circle"
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                            Label(
                                "Date & Time: \(load.pickupDate)",
                                systemImage: "clock"
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                            Label(
                                "Destination: \(load.deliveryLocation)",
                                systemImage: "mappin.and.ellipse"
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                            Label(
                                "Date & Time: \(load.dropoffDate)",
                                systemImage: "clock.fill"
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Assigned Loads")
        .onAppear {
            startListening()
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
        // ✅ Re-trigger if appUser loads after view appears
        .onChange(of: authManager.appUser?.name) { newName in
            guard let newName = newName, !newName.isEmpty else { return }
            guard listener == nil else { return }
            print("✅ Driver name now available via onChange: \(newName)")
            startListening()
        }
        .sheet(item: $selectedLoad) { load in
            LoadAcceptDeclineView(load: load) { action in
                handleAction(action, for: load)
            }
        }
    }

    // MARK: - Real-time Listener
    func startListening() {
        guard let driverName = authManager.appUser?.name,
              !driverName.isEmpty else {
            print("⚠️ Driver name not available yet — retrying...")
            guard listener == nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                startListening()
            }
            return
        }

        guard listener == nil else {
            print("✅ Listener already running for: \(driverName)")
            return
        }

        print("✅ Starting listener for driver: \(driverName)")

        listener = Firestore.firestore()
            .collection("loads")
            .whereField("assignedDriver", isEqualTo: driverName)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Driver loads error: \(error.localizedDescription)")
                    DispatchQueue.main.async { isLoading = false }
                    return
                }

                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { isLoading = false }
                    return
                }

                DispatchQueue.main.async {
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
                    isLoading = false
                    print("✅ Loads fetched: \(docs.count) total, \(activeLoads.count) active")
                }
            }
    }

    // MARK: - Handle Actions
    func handleAction(_ action: LoadAction, for load: DriverLoad) {
        let db = Firestore.firestore()

        switch action {

        case .accept:
            db.collection("loads").document(load.id).updateData([
                "status": "In Transit",
                "driverAccepted": true
            ])

        case .decline:
            db.collection("loads").document(load.id).updateData([
                "status": "Unassigned",
                "assignedDriver": "",
                "assignedVehicle": "",
                "driverAccepted": false,
                "declinedBy": authManager.appUser?.name ?? "Unknown"
            ])

        case .delivered:
            db.collection("loads").document(load.id).updateData([
                "status": "Delivered",
                "deliveredAt": Timestamp(),
                "deliveredBy": authManager.appUser?.name ?? "Unknown"
            ]) { error in
                if let error = error {
                    print("❌ Error marking delivered: \(error.localizedDescription)")
                }
            }
        }

        // ✅ Snapshot listener handles UI update automatically
        selectedLoad = nil
    }

    func statusColor(_ status: String) -> Color {
        switch status {
        case "Assigned":   return .blue
        case "In Transit": return .purple
        case "Delivered":  return .green
        default:           return .gray
        }
    }
}

// MARK: - Load Action Enum
enum LoadAction {
    case accept, decline, delivered
}

// MARK: - Accept / Decline / Delivered Sheet
struct LoadAcceptDeclineView: View {

    @Environment(\.dismiss) var dismiss
    let load: DriverLoad
    var onAction: (LoadAction) -> Void

    @State private var showDeclineConfirm = false
    @State private var showDeliveredConfirm = false

    var body: some View {
        NavigationStack {
            List {

                // LOAD DETAILS
                Section("Load Details") {
                    DetailRow(label: "Load ID", value: load.loadID)
                    DetailRow(label: "Pickup", value: load.pickupLocation)
                    DetailRow(label: "Pickup Date & Time", value: load.pickupDate)
                    DetailRow(label: "Destination", value: load.deliveryLocation)
                    DetailRow(label: "Destination Date & Time", value: load.dropoffDate)
                    DetailRow(label: "Current Status", value: load.status)
                }

                // ACTIONS
                Section("Actions") {

                    // ✅ Accept + Decline only when Assigned
                    if load.status.lowercased() == "assigned" {

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

                    // ✅ Mark as Delivered only when In Transit
                    if load.status.lowercased() == "in transit" {

                        Button {
                            showDeliveredConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "shippingbox.fill")
                                Text("Mark as Delivered")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }

                    // ✅ Delivered badge when already delivered
                    if load.status.lowercased() == "delivered" {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.green)
                                Text("This load has been delivered.")
                                    .foregroundColor(.green)
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Load \(load.loadID)")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") { dismiss() }
                }
            }

            // DECLINE CONFIRMATION
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

            // DELIVERED CONFIRMATION
            .confirmationDialog(
                "Mark as Delivered?",
                isPresented: $showDeliveredConfirm,
                titleVisibility: .visible
            ) {
                Button("Yes, Mark Delivered") {
                    onAction(.delivered)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will mark the load as delivered.")
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
