//
//  AssignLoadView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/10/26.
//
import SwiftUI
import FirebaseFirestore

struct AssignLoadView: View {

    var preselectedDriver: ScheduleDriver? = nil
    @State private var loads: [ScheduleLoad] = []
    @State private var drivers: [ScheduleDriver] = []
    @State private var selectedLoad: ScheduleLoad? = nil
    @State private var selectedDriver: ScheduleDriver? = nil
    @State private var isCheckingConflict = false
    @State private var showConfirmation = false
    @State private var showConflictWarning = false
    @State private var conflictMessage = ""
    @State private var isLoading = true
    @State private var listener: ListenerRegistration? = nil

    var body: some View {
        List {

            // STEP 1 - SELECT LOAD
            Section {
                HStack {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Select a Load")
                        .font(.headline)
                }
            }

            Section("Unassigned / Declined Loads") {
                if isLoading {
                    ProgressView("Loading loads...")
                } else if loads.isEmpty {
                    ContentUnavailableView(
                        "No Loads Available",
                        systemImage: "shippingbox",
                        description: Text("All loads are assigned.")
                    )
                } else {
                    ForEach(loads) { load in
                        Button {
                            withAnimation {
                                selectedLoad = load
                                selectedDriver = nil
                                fetchDriversWithAvailability()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Load ID: \(load.loadID)")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()

                                    // ✅ Show Declined badge if applicable
                                    if load.status == "Declined" {
                                        Text("Declined")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.red.opacity(0.15))
                                            .foregroundColor(.red)
                                            .clipShape(Capsule())
                                    }

                                    if selectedLoad?.id == load.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }

                                Label(
                                    "\(load.pickupLocation) → \(load.deliveryLocation)",
                                    systemImage: "arrow.right"
                                )
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                                HStack {
                                    Label(
                                        load.pickupDateTime.formatted(
                                            date: .abbreviated,
                                            time: .shortened
                                        ),
                                        systemImage: "clock"
                                    )
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                    Spacer()

                                    Text(load.duration)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .clipShape(Capsule())
                                }

                                if !load.commodity.isEmpty {
                                    Text("Cargo: \(load.commodity)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if !load.specialInstructions.isEmpty {
                                    Label(
                                        load.specialInstructions,
                                        systemImage: "exclamationmark.circle"
                                    )
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(
                            selectedLoad?.id == load.id
                            ? Color.blue.opacity(0.05)
                            : Color.clear
                        )
                    }
                }
            }

            // STEP 2 - SELECT DRIVER
            if selectedLoad != nil {
                Section {
                    HStack {
                        Image(systemName: "2.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        Text("Select an Available Driver")
                            .font(.headline)
                    }
                }

                Section("Drivers") {
                    ForEach(drivers) { driver in
                        Button {
                            withAnimation {
                                if driver.availabilityStatus != "Unavailable" {
                                    selectedDriver = driver
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(driver.name)
                                            .font(.headline)
                                            .foregroundColor(
                                                driver.availabilityStatus == "Unavailable"
                                                ? .gray : .primary
                                            )
                                        Text("Vehicle: \(driver.vehicleUnit)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()

                                    Text(driver.availabilityStatus)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            availabilityColor(driver.availabilityStatus).opacity(0.15)
                                        )
                                        .foregroundColor(availabilityColor(driver.availabilityStatus))
                                        .clipShape(Capsule())

                                    if selectedDriver?.id == driver.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }

                                if !driver.currentLoads.isEmpty {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Current Schedule:")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.secondary)

                                        ForEach(driver.currentLoads, id: \.self) { loadSummary in
                                            HStack(spacing: 4) {
                                                Circle()
                                                    .fill(Color.orange)
                                                    .frame(width: 6, height: 6)
                                                Text(loadSummary)
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.top, 2)
                                }

                                if driver.availabilityStatus == "Unavailable",
                                   let nextFree = driver.nextAvailableTime {
                                    Label(
                                        "Available: \(nextFree.formatted(date: .abbreviated, time: .shortened))",
                                        systemImage: "clock.badge.checkmark"
                                    )
                                    .font(.caption)
                                    .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .disabled(driver.availabilityStatus == "Unavailable")
                        .listRowBackground(
                            selectedDriver?.id == driver.id
                            ? Color.green.opacity(0.05)
                            : Color.clear
                        )
                    }
                }
            }

            // STEP 3 - CONFIRM ASSIGNMENT
            if selectedLoad != nil && selectedDriver != nil {
                Section {
                    HStack {
                        Image(systemName: "3.circle.fill")
                            .foregroundColor(.purple)
                            .font(.title2)
                        Text("Confirm Assignment")
                            .font(.headline)
                    }
                }

                Section("Summary") {
                    if let load = selectedLoad, let driver = selectedDriver {
                        VStack(alignment: .leading, spacing: 8) {
                            SummaryRow(icon: "shippingbox.fill", color: .blue, label: "Load", value: load.loadID)
                            SummaryRow(icon: "mappin.circle.fill", color: .red, label: "Pickup", value: "\(load.pickupLocation)\n\(load.pickupDateTime.formatted(date: .abbreviated, time: .shortened))")
                            SummaryRow(icon: "mappin.and.ellipse", color: .green, label: "Delivery", value: "\(load.deliveryLocation)\n\(load.deliveryDateTime.formatted(date: .abbreviated, time: .shortened))")
                            SummaryRow(icon: "person.fill", color: .purple, label: "Driver", value: driver.name)
                            SummaryRow(icon: "truck.box.fill", color: .orange, label: "Vehicle", value: driver.vehicleUnit)
                            SummaryRow(icon: "clock.fill", color: .teal, label: "Duration", value: load.duration)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button {
                        checkAndAssign()
                    } label: {
                        if isCheckingConflict {
                            HStack {
                                ProgressView()
                                Text("Checking schedule...")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Confirm & Assign Load")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .disabled(isCheckingConflict)
                }
            }
        }
        .navigationTitle("Assign Load")
        .onAppear {
            startListening()
            if let driver = preselectedDriver {
                selectedDriver = driver
            }
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
        .alert("Load Assigned!", isPresented: $showConfirmation) {
            Button("OK") {
                selectedLoad = nil
                selectedDriver = nil
            }
        } message: {
            if let load = selectedLoad, let driver = selectedDriver {
                Text("Load \(load.loadID) has been assigned to \(driver.name).")
            }
        }
        .alert("Scheduling Conflict", isPresented: $showConflictWarning) {
            Button("Assign Anyway", role: .destructive) { assignLoad() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(conflictMessage)
        }
    }

    // MARK: - Availability Color
    func availabilityColor(_ status: String) -> Color {
        switch status {
        case "Available":      return .green
        case "Available Soon": return .yellow
        case "Assigned":       return .blue
        case "In Transit":     return .orange
        case "Unavailable":    return .red
        default:               return .gray
        }
    }

    // MARK: - Real-time Listener
    // ✅ Fetches both Unassigned AND Declined so dispatcher can reassign
    func startListening() {
        isLoading = true
        listener?.remove()

        listener = Firestore.firestore()
            .collection("loads")
            .whereField("status", in: ["Unassigned", "Declined"])
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    loads = docs.map { doc in
                        let d = doc.data()
                        let pickupDT = (d["pickupDateTime"] as? Timestamp)?.dateValue() ?? Date()
                        let deliveryDT = (d["deliveryDateTime"] as? Timestamp)?.dateValue() ?? Date()
                        return ScheduleLoad(
                            id: doc.documentID,
                            loadID: d["loadID"] as? String ?? doc.documentID,
                            pickupLocation: d["pickupLocation"] as? String ?? "",
                            deliveryLocation: d["deliveryLocation"] as? String ?? "",
                            pickupDateTime: pickupDT,
                            deliveryDateTime: deliveryDT,
                            commodity: d["commodity"] as? String ?? "",
                            specialInstructions: d["specialInstructions"] as? String ?? "",
                            rate: d["rate"] as? String ?? "",
                            weight: d["weight"] as? String ?? "",
                            status: d["status"] as? String ?? "Unassigned"
                        )
                    }
                    .sorted { $0.pickupDateTime < $1.pickupDateTime }
                    isLoading = false
                    fetchDriversWithAvailability()
                }
            }
    }

    // MARK: - Fetch Drivers with Real Availability
    func fetchDriversWithAvailability() {
        Firestore.firestore()
            .collection("users")
            .whereField("role", isEqualTo: "Driver")
            .getDocuments { snapshot, _ in
                guard let driverDocs = snapshot?.documents else { return }

                let db = Firestore.firestore()
                var fetchedDrivers: [ScheduleDriver] = []
                let group = DispatchGroup()

                for driverDoc in driverDocs {
                    let d = driverDoc.data()
                    let name = d["name"] as? String ?? ""
                    let vehicleUnit = d["vehicleUnit"] as? String ?? "Unassigned"

                    group.enter()

                    // ✅ Include all active statuses
                    db.collection("loads")
                        .whereField("assignedDriver", isEqualTo: name)
                        .whereField("status", in: ["Assigned", "Accepted", "In Transit"])
                        .getDocuments { loadSnapshot, _ in

                            let activeDocs = loadSnapshot?.documents ?? []
                            var currentLoadSummaries: [String] = []
                            var latestEndTime: Date? = nil

                            for doc in activeDocs {
                                let ld = doc.data()
                                let loadID = ld["loadID"] as? String ?? "Unknown"
                                let status = ld["status"] as? String ?? ""
                                let deliveryDT = (ld["deliveryDateTime"] as? Timestamp)?.dateValue()

                                if let dt = deliveryDT {
                                    currentLoadSummaries.append(
                                        "\(loadID) — \(status) — Due: \(dt.formatted(date: .abbreviated, time: .shortened))"
                                    )
                                    if latestEndTime == nil || dt > latestEndTime! {
                                        latestEndTime = dt
                                    }
                                } else {
                                    currentLoadSummaries.append("\(loadID) — \(status)")
                                }
                            }

                            let availabilityStatus: String

                            if activeDocs.isEmpty {
                                availabilityStatus = "Available"
                            } else if let selectedLoad = self.selectedLoad {
                                let hasOverlap = activeDocs.contains { doc in
                                    let ld = doc.data()
                                    if let ep = (ld["pickupDateTime"] as? Timestamp)?.dateValue(),
                                       let ed = (ld["deliveryDateTime"] as? Timestamp)?.dateValue() {
                                        return selectedLoad.pickupDateTime < ed &&
                                               selectedLoad.deliveryDateTime > ep
                                    }
                                    return false
                                }

                                if hasOverlap {
                                    availabilityStatus = "Unavailable"
                                } else {
                                    let isInTransit = activeDocs.contains {
                                        ($0.data()["status"] as? String) == "In Transit"
                                    }
                                    availabilityStatus = isInTransit ? "Available Soon" : "Available"
                                }
                            } else {
                                let isInTransit = activeDocs.contains {
                                    ($0.data()["status"] as? String) == "In Transit"
                                }
                                availabilityStatus = isInTransit ? "In Transit" : "Assigned"
                            }

                            let driver = ScheduleDriver(
                                id: driverDoc.documentID,
                                name: name,
                                vehicleUnit: vehicleUnit,
                                availabilityStatus: availabilityStatus,
                                currentLoads: currentLoadSummaries,
                                nextAvailableTime: latestEndTime
                            )

                            fetchedDrivers.append(driver)
                            group.leave()
                        }
                }

                group.notify(queue: .main) {
                    drivers = fetchedDrivers.sorted {
                        availabilityPriority($0.availabilityStatus) <
                        availabilityPriority($1.availabilityStatus)
                    }
                }
            }
    }

    func availabilityPriority(_ status: String) -> Int {
        switch status {
        case "Available":      return 0
        case "Available Soon": return 1
        case "Assigned":       return 2
        case "In Transit":     return 3
        case "Unavailable":    return 4
        default:               return 5
        }
    }

    // MARK: - Check for Conflicts Then Assign
    func checkAndAssign() {
        guard let load = selectedLoad,
              let driver = selectedDriver else { return }

        isCheckingConflict = true

        Firestore.firestore()
            .collection("loads")
            .whereField("assignedDriver", isEqualTo: driver.name)
            .whereField("status", in: ["Assigned", "Accepted", "In Transit"])
            .getDocuments { snapshot, _ in
                DispatchQueue.main.async {
                    isCheckingConflict = false
                }

                let activeDocs = snapshot?.documents ?? []
                var conflictingLoads: [String] = []

                for doc in activeDocs {
                    let d = doc.data()
                    let existingPickup = (d["pickupDateTime"] as? Timestamp)?.dateValue()
                    let existingDelivery = (d["deliveryDateTime"] as? Timestamp)?.dateValue()
                    let existingLoadID = d["loadID"] as? String ?? "Unknown"

                    if let ep = existingPickup, let ed = existingDelivery {
                        let overlaps = load.pickupDateTime < ed &&
                                       load.deliveryDateTime > ep
                        if overlaps {
                            conflictingLoads.append(existingLoadID)
                        }
                    }
                }

                if conflictingLoads.isEmpty {
                    assignLoad()
                } else {
                    let loadList = conflictingLoads.joined(separator: ", ")
                    DispatchQueue.main.async {
                        conflictMessage = "\(driver.name) has overlapping load(s): \(loadList). Assign anyway?"
                        showConflictWarning = true
                    }
                }
            }
    }

    // MARK: - Assign Load
    func assignLoad() {
        guard let load = selectedLoad,
              let driver = selectedDriver else { return }

        // ✅ Build update data as typed dict to avoid FieldValue type mismatch
        let updateData: [String: Any] = [
            "assignedDriver": driver.name,
            "assignedDriverID": driver.id,
            "assignedVehicle": driver.vehicleUnit,
            "status": "Assigned",
            "assignedAt": Timestamp(),
            "declinedBy": ""
            // ✅ Removed FieldValue.delete() — just clear the field with ""
        ]

        Firestore.firestore()
            .collection("loads")
            .document(load.id)
            .updateData(updateData) { _ in
                DispatchQueue.main.async {
                    showConfirmation = true
                }
            }
    }

}

// MARK: - Summary Row
struct SummaryRow: View {
    let icon: String
    let color: Color
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Spacer()
        }
    }
}

// MARK: - Models
struct ScheduleLoad: Identifiable {
    let id: String
    var loadID: String
    var pickupLocation: String
    var deliveryLocation: String
    var pickupDateTime: Date
    var deliveryDateTime: Date
    var commodity: String
    var specialInstructions: String
    var rate: String
    var weight: String
    var status: String = "Unassigned"  // ✅ added

    var duration: String {
        let diff = deliveryDateTime.timeIntervalSince(pickupDateTime)
        let hours = Int(diff / 3600)
        let minutes = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }
}

struct ScheduleDriver: Identifiable {
    let id: String
    var name: String
    var vehicleUnit: String
    var availabilityStatus: String
    var currentLoads: [String]
    var nextAvailableTime: Date?
}
