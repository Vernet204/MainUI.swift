//
//  MaintenanceView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/14/26.
//


import SwiftUI
import FirebaseFirestore

struct MaintenanceView: View {

    @State private var records: [MaintenanceRecord] = []
    @State private var isLoading = true
    @State private var showAddMaintenance = false
    @State private var selectedRecord: MaintenanceRecord? = nil
    @State private var listener: ListenerRegistration? = nil
    @State private var filterStatus = "All"

    let filters = ["All", "Scheduled", "In Progress", "Completed", "Overdue"]

    var body: some View {
        List {

            // FILTER
            Section {
                Picker("Filter", selection: $filterStatus) {
                    ForEach(filters, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            // SUMMARY STATS
            Section {
                HStack(spacing: 0) {
                    StatCard(
                        title: "Total",
                        value: "\(records.count)",
                        color: .blue
                    )
                    Divider()
                    StatCard(
                        title: "Overdue",
                        value: "\(overdueCount)",
                        color: overdueCount > 0 ? .red : .green
                    )
                    Divider()
                    StatCard(
                        title: "Scheduled",
                        value: "\(scheduledCount)",
                        color: .orange
                    )
                }
            }

            // MAINTENANCE RECORDS
            Section("Maintenance Records") {
                if isLoading {
                    ProgressView("Loading...")
                } else if filteredRecords.isEmpty {
                    ContentUnavailableView(
                        "No Records",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("Add a maintenance record to get started.")
                    )
                } else {
                    ForEach(filteredRecords) { record in
                        Button {
                            selectedRecord = record
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {

                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Unit: \(record.vehicleUnit)")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(record.maintenanceType)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    // Status badge
                                    Text(record.status)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            statusColor(record.status).opacity(0.15)
                                        )
                                        .foregroundColor(statusColor(record.status))
                                        .clipShape(Capsule())
                                }

                                Divider()

                                HStack {
                                    Label(
                                        "Due: \(record.dueDate.formatted(date: .abbreviated, time: .omitted))",
                                        systemImage: "calendar"
                                    )
                                    .font(.caption)
                                    .foregroundColor(
                                        record.isOverdue ? .red : .secondary
                                    )

                                    Spacer()

                                    if !record.estimatedCost.isEmpty {
                                        Text("Est: $\(record.estimatedCost)")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }

                                if record.isOverdue {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.red)
                                            .font(.caption)
                                        Text("Overdue by \(record.daysOverdue) day(s)")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { deleteRecord(at: $0) }
                }
            }
        }
        .navigationTitle("Maintenance")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddMaintenance = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear { startListening() }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
        .refreshable { startListening() }
        .sheet(isPresented: $showAddMaintenance, onDismiss: startListening) {
            AddMaintenanceView()
        }
        .sheet(item: $selectedRecord) { record in
            MaintenanceDetailView(record: record) {
                startListening()
            }
        }
    }

    // MARK: - Filtered Records
    var filteredRecords: [MaintenanceRecord] {
        let sorted = records.sorted { $0.dueDate < $1.dueDate }
        if filterStatus == "All" { return sorted }
        if filterStatus == "Overdue" { return sorted.filter { $0.isOverdue } }
        return sorted.filter { $0.status == filterStatus }
    }

    var overdueCount: Int { records.filter { $0.isOverdue }.count }
    var scheduledCount: Int { records.filter { $0.status == "Scheduled" }.count }

    // MARK: - Status Color
    func statusColor(_ status: String) -> Color {
        switch status {
        case "Scheduled":   return .orange
        case "In Progress": return .blue
        case "Completed":   return .green
        case "Overdue":     return .red
        default:            return .gray
        }
    }

    // MARK: - Real-time Listener
    func startListening() {
        isLoading = true
        listener?.remove()

        listener = Firestore.firestore()
            .collection("maintenance")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Maintenance error: \(error.localizedDescription)")
                    return
                }

                guard let docs = snapshot?.documents else { return }

                DispatchQueue.main.async {
                    records = docs.compactMap { doc in
                        let d = doc.data()

                        guard let dueTimestamp = d["dueDate"] as? Timestamp else {
                            return nil
                        }

                        return MaintenanceRecord(
                            id: doc.documentID,
                            vehicleUnit: d["vehicleUnit"] as? String ?? "",
                            vehiclePlate: d["vehiclePlate"] as? String ?? "",
                            maintenanceType: d["maintenanceType"] as? String ?? "",
                            description: d["description"] as? String ?? "",
                            status: d["status"] as? String ?? "Scheduled",
                            dueDate: dueTimestamp.dateValue(),
                            completedDate: (d["completedDate"] as? Timestamp)?.dateValue(),
                            estimatedCost: d["estimatedCost"] as? String ?? "",
                            actualCost: d["actualCost"] as? String ?? "",
                            mileageAtService: d["mileageAtService"] as? String ?? "",
                            technicianName: d["technicianName"] as? String ?? "",
                            notes: d["notes"] as? String ?? ""
                        )
                    }
                    isLoading = false
                }
            }
    }

    // MARK: - Delete Record
    func deleteRecord(at indexSet: IndexSet) {
        indexSet.forEach { index in
            let record = filteredRecords[index]
            Firestore.firestore()
                .collection("maintenance")
                .document(record.id)
                .delete()
        }
    }
}

// MARK: - Add Maintenance View
struct AddMaintenanceView: View {

    @Environment(\.dismiss) var dismiss

    @State private var vehicleUnit = ""
    @State private var vehiclePlate = ""
    @State private var maintenanceType = "Oil Change"
    @State private var description = ""
    @State private var dueDate = Date()
    @State private var estimatedCost = ""
    @State private var mileageAtService = ""
    @State private var technicianName = ""
    @State private var notes = ""
    @State private var status = "Scheduled"
    @State private var errorMessage = ""
    @State private var vehicles: [Vehicle] = []

    let maintenanceTypes = [
        "Oil Change",
        "Tire Rotation",
        "Brake Inspection",
        "Engine Tune-Up",
        "Transmission Service",
        "Coolant Flush",
        "Air Filter",
        "Fuel Filter",
        "Battery Replacement",
        "DOT Inspection",
        "Other"
    ]

    let statuses = ["Scheduled", "In Progress", "Completed"]

    var body: some View {
        NavigationStack {
            Form {

                // VEHICLE INFO
                Section("Vehicle") {
                    Picker("Select Vehicle", selection: $vehicleUnit) {
                        Text("Select...").tag("")
                        ForEach(vehicles) { v in
                            Text("Unit \(v.unitNumber) — \(v.plate)").tag(v.unitNumber)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: vehicleUnit) { unit in
                        if let v = vehicles.first(where: { $0.unitNumber == unit }) {
                            vehiclePlate = v.plate
                        }
                    }

                    if !vehiclePlate.isEmpty {
                        DetailRow(label: "Plate", value: vehiclePlate)
                    }
                }

                // MAINTENANCE INFO
                Section("Maintenance Info") {
                    Picker("Type", selection: $maintenanceType) {
                        ForEach(maintenanceTypes, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)

                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)

                    DatePicker(
                        "Due Date",
                        selection: $dueDate,
                        displayedComponents: .date
                    )

                    Picker("Status", selection: $status) {
                        ForEach(statuses, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                // COST & SERVICE
                Section("Cost & Service") {
                    TextField("Estimated Cost ($)", text: $estimatedCost)
                        .keyboardType(.decimalPad)
                    TextField("Mileage at Service", text: $mileageAtService)
                        .keyboardType(.numberPad)
                    TextField("Technician Name", text: $technicianName)
                }

                // NOTES
                Section("Notes") {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Maintenance")
            .onAppear { fetchVehicles() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRecord() }
                }
            }
        }
    }

    // MARK: - Fetch Vehicles
    func fetchVehicles() {
        Firestore.firestore()
            .collection("vehicles")
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    vehicles = docs.map { doc in
                        let d = doc.data()
                        return Vehicle(
                            unitNumber: d["unitNumber"] as? String ?? "",
                            plate: d["plate"] as? String ?? "",
                            status: d["status"] as? String ?? ""
                        )
                    }
                }
            }
    }

    // MARK: - Save Record
    func saveRecord() {
        guard !vehicleUnit.isEmpty else {
            errorMessage = "Please select a vehicle."
            return
        }

        Firestore.firestore()
            .collection("maintenance")
            .addDocument(data: [
                "vehicleUnit": vehicleUnit,
                "vehiclePlate": vehiclePlate,
                "maintenanceType": maintenanceType,
                "description": description,
                "status": status,
                "dueDate": Timestamp(date: dueDate),
                "estimatedCost": estimatedCost,
                "mileageAtService": mileageAtService,
                "technicianName": technicianName,
                "notes": notes,
                "createdAt": Timestamp()
            ]) { error in
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    dismiss()
                }
            }
    }
}

// MARK: - Maintenance Detail View
struct MaintenanceDetailView: View {

    @Environment(\.dismiss) var dismiss
    let record: MaintenanceRecord
    var onDismiss: () -> Void

    @State private var showMarkComplete = false
    @State private var actualCost = ""
    @State private var completionNotes = ""

    var body: some View {
        NavigationStack {
            List {

                // STATUS BANNER
                Section {
                    HStack {
                        Image(systemName: statusIcon(record.status))
                            .foregroundColor(statusColor(record.status))
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text(record.status)
                                .font(.headline)
                                .foregroundColor(statusColor(record.status))
                            if record.isOverdue {
                                Text("Overdue by \(record.daysOverdue) day(s)")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                // VEHICLE INFO
                Section("Vehicle") {
                    DetailRow(label: "Unit Number", value: record.vehicleUnit)
                    DetailRow(label: "Plate", value: record.vehiclePlate)
                }

                // MAINTENANCE INFO
                Section("Maintenance Info") {
                    DetailRow(label: "Type", value: record.maintenanceType)
                    DetailRow(
                        label: "Description",
                        value: record.description.isEmpty ? "—" : record.description
                    )
                    DetailRow(
                        label: "Due Date",
                        value: record.dueDate.formatted(date: .long, time: .omitted)
                    )
                    if let completedDate = record.completedDate {
                        DetailRow(
                            label: "Completed Date",
                            value: completedDate.formatted(date: .long, time: .omitted)
                        )
                    }
                }

                // COST & SERVICE
                Section("Cost & Service") {
                    DetailRow(
                        label: "Estimated Cost",
                        value: record.estimatedCost.isEmpty ? "—" : "$\(record.estimatedCost)"
                    )
                    DetailRow(
                        label: "Actual Cost",
                        value: record.actualCost.isEmpty ? "—" : "$\(record.actualCost)"
                    )
                    DetailRow(
                        label: "Mileage",
                        value: record.mileageAtService.isEmpty ? "—" : "\(record.mileageAtService) mi"
                    )
                    DetailRow(
                        label: "Technician",
                        value: record.technicianName.isEmpty ? "—" : record.technicianName
                    )
                }

                // NOTES
                if !record.notes.isEmpty {
                    Section("Notes") {
                        Text(record.notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK COMPLETE BUTTON
                if record.status != "Completed" {
                    Section {
                        Button {
                            showMarkComplete = true
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Mark as Completed")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .navigationTitle("\(record.maintenanceType)")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
            // MARK COMPLETE SHEET
            .sheet(isPresented: $showMarkComplete) {
                MarkCompleteView(
                    record: record,
                    onComplete: {
                        onDismiss()
                        dismiss()
                    }
                )
            }
        }
    }

    func statusColor(_ status: String) -> Color {
        switch status {
        case "Scheduled":   return .orange
        case "In Progress": return .blue
        case "Completed":   return .green
        default:            return .red
        }
    }

    func statusIcon(_ status: String) -> String {
        switch status {
        case "Scheduled":   return "calendar.badge.clock"
        case "In Progress": return "wrench.and.screwdriver.fill"
        case "Completed":   return "checkmark.seal.fill"
        default:            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Mark Complete View
struct MarkCompleteView: View {

    @Environment(\.dismiss) var dismiss
    let record: MaintenanceRecord
    var onComplete: () -> Void

    @State private var actualCost = ""
    @State private var completionNotes = ""
    @State private var completedDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Completion Details") {
                    DatePicker(
                        "Completed Date",
                        selection: $completedDate,
                        displayedComponents: .date
                    )
                    TextField("Actual Cost ($)", text: $actualCost)
                        .keyboardType(.decimalPad)
                    TextField("Completion Notes...", text: $completionNotes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    Button {
                        markComplete()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Confirm Complete")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .navigationTitle("Mark Complete")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    func markComplete() {
        Firestore.firestore()
            .collection("maintenance")
            .document(record.id)
            .updateData([
                "status": "Completed",
                "completedDate": Timestamp(date: completedDate),
                "actualCost": actualCost,
                "notes": completionNotes
            ]) { error in
                if let error = error {
                    print("❌ Error marking complete: \(error.localizedDescription)")
                } else {
                    onComplete()
                    dismiss()
                }
            }
    }
}

// MARK: - Maintenance Record Model
struct MaintenanceRecord: Identifiable {
    let id: String
    var vehicleUnit: String
    var vehiclePlate: String
    var maintenanceType: String
    var description: String
    var status: String
    var dueDate: Date
    var completedDate: Date?
    var estimatedCost: String
    var actualCost: String
    var mileageAtService: String
    var technicianName: String
    var notes: String

    // ✅ Auto calculate if overdue
    var isOverdue: Bool {
        status != "Completed" && dueDate < Date()
    }

    var daysOverdue: Int {
        guard isOverdue else { return 0 }
        return Calendar.current.dateComponents(
            [.day],
            from: dueDate,
            to: Date()
        ).day ?? 0
    }
}
