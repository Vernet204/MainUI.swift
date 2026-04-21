//
//  DriverDashboardView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/29/26.
//
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct DriverDashboardView: View {

    @EnvironmentObject var authManager: AuthManager

    // MARK: - Live Stats
    @State private var activeLoadsCount = 0
    @State private var deliveredCount = 0
    @State private var currentLoad: DriverLoad? = nil
    @State private var assignedVehicle = ""

    // MARK: - Listener
    @State private var listener: ListenerRegistration? = nil
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // MARK: - Driver Stats
                    VStack(alignment: .leading, spacing: 10) {
                        Text("My Overview")
                            .font(.headline)
                            .padding(.horizontal)

                        HStack(spacing: 12) {
                            DriverStatCard(
                                value: "\(activeLoadsCount)",
                                label: "Active Loads",
                                icon: "shippingbox.fill",
                                color: activeLoadsCount > 0 ? .blue : .gray
                            )
                            DriverStatCard(
                                value: "\(deliveredCount)",
                                label: "Delivered",
                                icon: "checkmark.seal.fill",
                                color: .green
                            )
                            DriverStatCard(
                                value: assignedVehicle.isEmpty ? "None" : assignedVehicle,
                                label: "My Vehicle",
                                icon: "truck.box.fill",
                                color: assignedVehicle.isEmpty ? .gray : .blue
                            )
                        }
                        .padding(.horizontal)
                    }

                    // MARK: - Current Load Card (shown when In Transit or Accepted)
                    if let load = currentLoad,
                       ["accepted", "in transit"].contains(load.status.lowercased()) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: load.status.lowercased() == "in transit"
                                      ? "truck.box.fill" : "checkmark.seal.fill")
                                    .foregroundColor(load.status.lowercased() == "in transit"
                                                     ? .purple : .green)
                                Text(load.status.lowercased() == "in transit"
                                     ? "Currently On The Road"
                                     : "Load Ready to Start")
                                    .font(.headline)
                                    .foregroundColor(load.status.lowercased() == "in transit"
                                                     ? .purple : .green)
                            }
                            .padding(.horizontal)

                            NavigationLink(destination: DriverLoadBoardView()) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("Load \(load.loadID)")
                                            .font(.headline)
                                        Spacer()
                                        Text(load.status)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(
                                                statusColor(load.status).opacity(0.15)
                                            )
                                            .foregroundColor(statusColor(load.status))
                                            .clipShape(Capsule())
                                    }

                                    Divider()

                                    HStack(spacing: 8) {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(.green)
                                        Text(load.pickupLocation)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    HStack(spacing: 8) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .foregroundColor(.red)
                                        Text(load.deliveryLocation)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }

                                    HStack(spacing: 8) {
                                        Image(systemName: "clock.fill")
                                            .foregroundColor(.orange)
                                        Text("Deliver by: \(load.dropoffDate)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    // ✅ Action hint
                                    HStack {
                                        Spacer()
                                        Text(load.status.lowercased() == "in transit"
                                             ? "Tap to mark as Delivered →"
                                             : "Tap to Start Trip →")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(statusColor(load.status))
                                    }
                                }
                                .padding()
                                .background(statusColor(load.status).opacity(0.06))
                                .cornerRadius(14)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(statusColor(load.status).opacity(0.3), lineWidth: 1.5)
                                )
                                .padding(.horizontal)
                            }
                        }
                    }

                    // MARK: - Pending Acceptance Banner
                    if let load = currentLoad, load.status.lowercased() == "assigned" {
                        NavigationLink(destination: DriverLoadBoardView()) {
                            HStack(spacing: 12) {
                                Image(systemName: "bell.badge.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("New Load Assigned!")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Load \(load.loadID) is waiting for your response.")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.85))
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(14)
                            .padding(.horizontal)
                        }
                    }

                    // MARK: - Quick Actions
                    VStack(alignment: .leading, spacing: 10) {
                        Text("My Loads")
                            .font(.headline)
                            .padding(.horizontal)

                        NavigationLink(destination: DriverLoadBoardView()) {
                            HStack {
                                Image(systemName: "list.bullet.rectangle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.blue)
                                    .cornerRadius(12)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Assigned Loads")
                                        .font(.headline)
                                    Text("\(activeLoadsCount) active load\(activeLoadsCount == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(14)
                            .padding(.horizontal)
                        }
                    }

                    // MARK: - Reports
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reports")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(spacing: 10) {
                            DriverReportLink(
                                title: "DVIR Inspection",
                                subtitle: "Daily vehicle inspection",
                                icon: "checkmark.shield.fill",
                                color: .green,
                                destination: AnyView(DVIRInspectionView())
                            )
                            DriverReportLink(
                                title: "Repair Report",
                                subtitle: "Report a vehicle issue",
                                icon: "wrench.and.screwdriver.fill",
                                color: .orange,
                                destination: AnyView(RepairReportView())
                            )
                            DriverReportLink(
                                title: "Report an Accident",
                                subtitle: "Emergency incident report",
                                icon: "exclamationmark.triangle.fill",
                                color: .red,
                                destination: AnyView(AccidentReportView())
                            )
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
                .padding(.vertical)
            }
            .navigationTitle("Driver Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Logout") {
                        authManager.logout()
                    }
                    .foregroundColor(.red)
                }
            }
            .onAppear { startListening() }
            .onDisappear {
                listener?.remove()
                listener = nil
            }
            .onChange(of: authManager.appUser?.name) { _, newName in
                guard let newName = newName, !newName.isEmpty else { return }
                guard listener == nil else { return }
                startListening()
            }
        }
    }

    // MARK: - Listener
    func startListening() {
        guard let driverName = authManager.appUser?.name,
              !driverName.isEmpty else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                startListening()
            }
            return
        }

        guard listener == nil else { return }

        // ✅ Fetch vehicle assignment from Firestore
        if let uid = Auth.auth().currentUser?.uid {
            Firestore.firestore()
                .collection("users")
                .document(uid)
                .getDocument { snapshot, _ in
                    if let data = snapshot?.data(),
                       let unit = data["vehicleUnit"] as? String,
                       !unit.isEmpty {
                        DispatchQueue.main.async {
                            assignedVehicle = unit
                        }
                    }
                }
        }

        listener = Firestore.firestore()
            .collection("loads")
            .whereField("assignedDriver", isEqualTo: driverName)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }

                var active = 0
                var delivered = 0
                var current: DriverLoad? = nil

                // Priority: In Transit > Accepted > Assigned
                var inTransitLoad: DriverLoad? = nil
                var acceptedLoad: DriverLoad? = nil
                var assignedLoad: DriverLoad? = nil

                for doc in docs {
                    let d = doc.data()
                    let status = d["status"] as? String ?? ""
                    let pickupDT = (d["pickupDateTime"] as? Timestamp)?.dateValue() ?? Date()
                    let deliveryDT = (d["deliveryDateTime"] as? Timestamp)?.dateValue() ?? Date()

                    let load = DriverLoad(
                        id: doc.documentID,
                        loadID: d["loadID"] as? String ?? doc.documentID,
                        pickupLocation: d["pickupLocation"] as? String ?? "",
                        deliveryLocation: d["deliveryLocation"] as? String ?? "",
                        pickupDate: pickupDT.formatted(date: .abbreviated, time: .shortened),
                        dropoffDate: deliveryDT.formatted(date: .abbreviated, time: .shortened),
                        status: status
                    )

                    switch status.lowercased() {
                    case "assigned":
                        active += 1
                        if assignedLoad == nil { assignedLoad = load }
                    case "accepted":
                        active += 1
                        if acceptedLoad == nil { acceptedLoad = load }
                    case "in transit":
                        active += 1
                        if inTransitLoad == nil { inTransitLoad = load }
                    case "delivered":
                        delivered += 1
                    default:
                        break
                    }
                }

                // ✅ Show most urgent load
                current = inTransitLoad ?? acceptedLoad ?? assignedLoad

                DispatchQueue.main.async {
                    activeLoadsCount = active
                    deliveredCount = delivered
                    currentLoad = current
                    isLoading = false
                }
            }
    }

    func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "assigned":   return .blue
        case "accepted":   return .green
        case "in transit": return .purple
        case "delivered":  return .green
        default:           return .gray
        }
    }
}

// MARK: - Driver Stat Card
struct DriverStatCard: View {
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
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
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

// MARK: - Driver Report Link
struct DriverReportLink: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: AnyView

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(color)
                    .cornerRadius(12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(14)
        }
    }
}

// MARK: - Driver Load Board
struct DriverLoadBoardView: View {

    @EnvironmentObject var authManager: AuthManager
    @State private var loads: [DriverLoad] = []
    @State private var selectedLoad: DriverLoad? = nil
    @State private var isLoading = true
    @State private var listener: ListenerRegistration? = nil

    var activeLoads: [DriverLoad] {
        loads.filter {
            !["delivered", "declined"].contains($0.status.lowercased())
        }
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

                            Label("Pickup: \(load.pickupLocation)", systemImage: "mappin.circle")
                                .font(.subheadline).foregroundColor(.secondary)
                            Label("Date & Time: \(load.pickupDate)", systemImage: "clock")
                                .font(.subheadline).foregroundColor(.secondary)
                            Label("Destination: \(load.deliveryLocation)", systemImage: "mappin.and.ellipse")
                                .font(.subheadline).foregroundColor(.secondary)
                            Label("Date & Time: \(load.dropoffDate)", systemImage: "clock.fill")
                                .font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
            }
        }
        .navigationTitle("Assigned Loads")
        .onAppear { startListening() }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
        .onChange(of: authManager.appUser?.name) { _, newName in
            guard let newName = newName, !newName.isEmpty else { return }
            guard listener == nil else { return }
            startListening()
        }
        .sheet(item: $selectedLoad) { load in
            LoadAcceptDeclineView(load: load) { action in
                handleAction(action, for: load)
            }
        }
    }

    func startListening() {
        guard let driverName = authManager.appUser?.name,
              !driverName.isEmpty else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                startListening()
            }
            return
        }

        guard listener == nil else { return }

        listener = Firestore.firestore()
            .collection("loads")
            .whereField("assignedDriver", isEqualTo: driverName)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else {
                    DispatchQueue.main.async { isLoading = false }
                    return
                }

                DispatchQueue.main.async {
                    loads = docs.map { doc in
                        let d = doc.data()
                        let pickupDT = (d["pickupDateTime"] as? Timestamp)?.dateValue() ?? Date()
                        let deliveryDT = (d["deliveryDateTime"] as? Timestamp)?.dateValue() ?? Date()
                        return DriverLoad(
                            id: doc.documentID,
                            loadID: d["loadID"] as? String ?? doc.documentID,
                            pickupLocation: d["pickupLocation"] as? String ?? "",
                            deliveryLocation: d["deliveryLocation"] as? String ?? "",
                            pickupDate: pickupDT.formatted(date: .abbreviated, time: .shortened),
                            dropoffDate: deliveryDT.formatted(date: .abbreviated, time: .shortened),
                            status: d["status"] as? String ?? "Assigned"
                        )
                    }
                    isLoading = false
                }
            }
    }

    func handleAction(_ action: LoadAction, for load: DriverLoad) {
        let db = Firestore.firestore()
        let driverName = authManager.appUser?.name ?? "Unknown"

        switch action {
        case .accept:
            db.collection("loads").document(load.id).updateData([
                "status": "Accepted",
                "acceptedAt": Timestamp(),
                "acceptedBy": driverName
            ] as [String: Any])

        case .decline:
            db.collection("loads").document(load.id).updateData([
                "status": "Declined",
                "assignedDriver": "",
                "assignedVehicle": "",
                "declinedAt": Timestamp(),
                "declinedBy": driverName
            ] as [String: Any])

        case .inTransit:
            db.collection("loads").document(load.id).updateData([
                "status": "In Transit",
                "transitStartedAt": Timestamp()
            ] as [String: Any])

        case .delivered:
            db.collection("loads").document(load.id).updateData([
                "status": "Delivered",
                "deliveredAt": Timestamp(),
                "deliveredBy": driverName
            ] as [String: Any])
        }

        selectedLoad = nil
    }

    func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "assigned":   return .blue
        case "accepted":   return .green
        case "in transit": return .purple
        case "delivered":  return .green
        default:           return .gray
        }
    }
}

// MARK: - Load Action Enum
enum LoadAction {
    case accept, decline, inTransit, delivered
}

// MARK: - Accept / Decline / Status Sheet
struct LoadAcceptDeclineView: View {

    @Environment(\.dismiss) var dismiss
    let load: DriverLoad
    var onAction: (LoadAction) -> Void

    @State private var showDeclineConfirm = false
    @State private var showInTransitConfirm = false
    @State private var showDeliveredConfirm = false

    var body: some View {
        NavigationStack {
            List {

                Section("Load Details") {
                    DetailRow(label: "Load ID", value: load.loadID)
                    DetailRow(label: "Pickup", value: load.pickupLocation)
                    DetailRow(label: "Pickup Date & Time", value: load.pickupDate)
                    DetailRow(label: "Destination", value: load.deliveryLocation)
                    DetailRow(label: "Delivery Date & Time", value: load.dropoffDate)
                    DetailRow(label: "Current Status", value: load.status)
                }

                Section("Actions") {

                    if load.status.lowercased() == "assigned" {
                        Button {
                            onAction(.accept)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Accept Load").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.green).foregroundColor(.white).cornerRadius(12)
                        }

                        Button {
                            showDeclineConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Decline Load").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.red).foregroundColor(.white).cornerRadius(12)
                        }
                    }

                    if load.status.lowercased() == "accepted" {
                        HStack {
                            Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                            Text("Load Accepted").fontWeight(.semibold).foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity).padding()

                        Button {
                            showInTransitConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "truck.box.fill")
                                Text("Start Trip — Mark In Transit").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.purple).foregroundColor(.white).cornerRadius(12)
                        }
                    }

                    if load.status.lowercased() == "in transit" {
                        HStack {
                            Image(systemName: "truck.box.fill").foregroundColor(.purple)
                            Text("Currently In Transit").fontWeight(.semibold).foregroundColor(.purple)
                        }
                        .frame(maxWidth: .infinity).padding()

                        Button {
                            showDeliveredConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "shippingbox.fill")
                                Text("Mark as Delivered").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                        }
                    }

                    if load.status.lowercased() == "declined" {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "xmark.seal.fill")
                                    .font(.largeTitle).foregroundColor(.red)
                                Text("Load Declined").fontWeight(.semibold).foregroundColor(.red)
                                Text("This load has been sent back to your dispatcher.")
                                    .font(.caption).foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            Spacer()
                        }
                        .padding()
                    }

                    if load.status.lowercased() == "delivered" {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.largeTitle).foregroundColor(.green)
                                Text("Load Delivered").fontWeight(.semibold).foregroundColor(.green)
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
            .confirmationDialog("Decline this load?", isPresented: $showDeclineConfirm, titleVisibility: .visible) {
                Button("Yes, Decline", role: .destructive) { onAction(.decline); dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This load will be sent back to your dispatcher for reassignment.")
            }
            .confirmationDialog("Start trip?", isPresented: $showInTransitConfirm, titleVisibility: .visible) {
                Button("Yes, Start Trip") { onAction(.inTransit); dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will mark the load as In Transit.")
            }
            .confirmationDialog("Mark as Delivered?", isPresented: $showDeliveredConfirm, titleVisibility: .visible) {
                Button("Yes, Mark Delivered") { onAction(.delivered); dismiss() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will mark the load as Delivered.")
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
