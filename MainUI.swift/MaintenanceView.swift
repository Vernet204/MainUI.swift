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
    // ✅ Vehicle filter
    @State private var filterVehicle = "All Vehicles"

    let filters = ["All", "Scheduled", "In Progress", "Due Soon", "Overdue", "Completed"]

    // MARK: - Computed Stats
    var overdueCount: Int  { records.filter { $0.isOverdue }.count }
    var dueSoonCount: Int  { records.filter { $0.isDueSoon }.count }
    var scheduledCount: Int { records.filter { $0.status == "Scheduled" }.count }

    // ✅ Total estimated cost across all non-completed records
    var totalEstimatedCost: Double {
        records
            .filter { $0.status != "Completed" }
            .compactMap { Double($0.estimatedCost) }
            .reduce(0, +)
    }

    // ✅ Total actual cost from completed records
    var totalActualCost: Double {
        records
            .filter { $0.status == "Completed" }
            .compactMap { Double($0.actualCost) }
            .reduce(0, +)
    }

    // ✅ Unique vehicle units for the vehicle filter picker
    var vehicleOptions: [String] {
        let units = Set(records.map { $0.vehicleUnit }).filter { !$0.isEmpty }.sorted()
        return ["All Vehicles"] + units
    }

    var filteredRecords: [MaintenanceRecord] {
        var result = records

        // ✅ Apply vehicle filter first
        if filterVehicle != "All Vehicles" {
            result = result.filter { $0.vehicleUnit == filterVehicle }
        }

        // Apply status filter
        switch filterStatus {
        case "Overdue":    result = result.filter { $0.isOverdue }
        case "Due Soon":   result = result.filter { $0.isDueSoon && !$0.isOverdue }
        case "Completed":  result = result.filter { $0.status == "Completed" }
        case "All":        result = result.filter { $0.status != "Completed" }
        default:           result = result.filter { $0.status == filterStatus }
        }

        // Sort: overdue first, then by due date
        return result.sorted {
            if $0.isOverdue != $1.isOverdue { return $0.isOverdue }
            return $0.dueDate < $1.dueDate
        }
    }

    var body: some View {
        List {

            // MARK: - Status Filter
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(filters, id: \.self) { filter in
                            Button {
                                filterStatus = filter
                            } label: {
                                Text(filter)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        filterStatus == filter
                                        ? filterColor(filter)
                                        : Color(.systemGray5)
                                    )
                                    .foregroundColor(
                                        filterStatus == filter ? .white : .primary
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // ✅ Vehicle filter picker
            Section {
                Picker("Filter by Vehicle", selection: $filterVehicle) {
                    ForEach(vehicleOptions, id: \.self) { Text($0) }
                }
                .pickerStyle(.menu)
            }

            // MARK: - Summary Stats
            Section {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    MaintenanceStatCard(
                        value: "\(overdueCount)",
                        label: "Overdue",
                        color: overdueCount > 0 ? .red : .gray
                    )
                    MaintenanceStatCard(
                        value: "\(dueSoonCount)",
                        label: "Due Soon",
                        color: dueSoonCount > 0 ? .orange : .gray
                    )
                    MaintenanceStatCard(
                        value: "\(scheduledCount)",
                        label: "Scheduled",
                        color: .blue
                    )
                    MaintenanceStatCard(
                        value: "$\(Int(totalActualCost))",
                        label: "Total Spent",
                        color: .green
                    )
                }
            }

            // MARK: - Records
            Section("Maintenance Records") {
                if isLoading {
                    ProgressView("Loading...")
                } else if filteredRecords.isEmpty {
                    ContentUnavailableView(
                        "No Records",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("No maintenance records match the current filter.")
                    )
                } else {
                    ForEach(filteredRecords) { record in
                        Button {
                            selectedRecord = record
                        } label: {
                            MaintenanceRecordRow(record: record)
                        }
                    }
                    .onDelete { deleteRecord(at: $0) }
                }
            }
        }
        .navigationTitle("Maintenance")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddMaintenance = true } label: {
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

    func filterColor(_ filter: String) -> Color {
        switch filter {
        case "Overdue":    return .red
        case "Due Soon":   return .orange
        case "Scheduled":  return .blue
        case "In Progress": return .purple
        case "Completed":  return .green
        default:           return .gray
        }
    }

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
                        guard let dueTimestamp = d["dueDate"] as? Timestamp else { return nil }
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
                            notes: d["notes"] as? String ?? "",
                            sourceReportNumber: d["sourceReportNumber"] as? String ?? "",
                            reportedBy: d["reportedBy"] as? String ?? ""
                        )
                    }
                    isLoading = false
                }
            }
    }

    func deleteRecord(at indexSet: IndexSet) {
        indexSet.forEach { index in
            let record = filteredRecords[index]
            Firestore.firestore().collection("maintenance").document(record.id).delete()
        }
    }
}

// MARK: - Maintenance Record Row
struct MaintenanceRecordRow: View {
    let record: MaintenanceRecord

    var body: some View {
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
                Text(displayStatus(record))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(record).opacity(0.15))
                    .foregroundColor(statusColor(record))
                    .clipShape(Capsule())
            }

            Divider()

            HStack {
                Label(
                    "Due: \(record.dueDate.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "calendar"
                )
                .font(.caption)
                .foregroundColor(record.isOverdue ? .red : record.isDueSoon ? .orange : .secondary)

                Spacer()

                if !record.estimatedCost.isEmpty {
                    Text("Est: $\(record.estimatedCost)")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            // ✅ Source report badge — shows where this record came from
            if !record.sourceReportNumber.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("From \(record.sourceReportNumber)")
                        .font(.caption2)
                        .foregroundColor(.blue)
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
            } else if record.isDueSoon {
                HStack(spacing: 4) {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Due in \(record.daysUntilDue) day(s)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }

    func displayStatus(_ record: MaintenanceRecord) -> String {
        if record.isOverdue && record.status != "Completed" { return "Overdue" }
        if record.isDueSoon && record.status != "Completed" { return "Due Soon" }
        return record.status
    }

    func statusColor(_ record: MaintenanceRecord) -> Color {
        if record.isOverdue && record.status != "Completed" { return .red }
        if record.isDueSoon && record.status != "Completed" { return .orange }
        switch record.status {
        case "Scheduled":   return .blue
        case "In Progress": return .purple
        case "Completed":   return .green
        default:            return .gray
        }
    }
}

// MARK: - Maintenance Stat Card
struct MaintenanceStatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
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
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .cornerRadius(10)
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
        "Oil Change", "Tire Rotation", "Brake Inspection", "Engine Tune-Up",
        "Transmission Service", "Coolant Flush", "Air Filter", "Fuel Filter",
        "Battery Replacement", "DOT Inspection", "DVIR Defect Repair", "Other"
    ]
    let statuses = ["Scheduled", "In Progress", "Completed"]

    var body: some View {
        NavigationStack {
            Form {
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

                Section("Maintenance Info") {
                    Picker("Type", selection: $maintenanceType) {
                        ForEach(maintenanceTypes, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)

                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...4)

                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)

                    Picker("Status", selection: $status) {
                        ForEach(statuses, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Cost & Service") {
                    TextField("Estimated Cost ($)", text: $estimatedCost)
                        .keyboardType(.decimalPad)
                    TextField("Mileage at Service", text: $mileageAtService)
                        .keyboardType(.numberPad)
                    TextField("Technician Name", text: $technicianName)
                }

                Section("Notes") {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage).foregroundColor(.red).font(.caption)
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

    func fetchVehicles() {
        Firestore.firestore().collection("vehicles")
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

    func saveRecord() {
        guard !vehicleUnit.isEmpty else { errorMessage = "Please select a vehicle."; return }

        Firestore.firestore().collection("maintenance")
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
                "sourceReportNumber": "",
                "reportedBy": "",
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
                            Text(record.isOverdue && record.status != "Completed"
                                 ? "Overdue" : record.status)
                                .font(.headline)
                                .foregroundColor(statusColor(record.status))
                            if record.isOverdue && record.status != "Completed" {
                                Text("Overdue by \(record.daysOverdue) day(s)")
                                    .font(.caption).foregroundColor(.red)
                            } else if record.isDueSoon && record.status != "Completed" {
                                Text("Due in \(record.daysUntilDue) day(s)")
                                    .font(.caption).foregroundColor(.orange)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                Section("Vehicle") {
                    DetailRow(label: "Unit Number", value: record.vehicleUnit)
                    DetailRow(label: "Plate", value: record.vehiclePlate)
                }

                Section("Maintenance Info") {
                    DetailRow(label: "Type", value: record.maintenanceType)
                    if !record.description.isEmpty {
                        DetailRow(label: "Description", value: record.description)
                    }
                    DetailRow(
                        label: "Due Date",
                        value: record.dueDate.formatted(date: .long, time: .omitted)
                    )
                    if let completedDate = record.completedDate {
                        DetailRow(
                            label: "Completed",
                            value: completedDate.formatted(date: .long, time: .omitted)
                        )
                    }
                }

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
                        value: record.mileageAtService.isEmpty
                            ? "—" : "\(record.mileageAtService) mi"
                    )
                    DetailRow(
                        label: "Technician",
                        value: record.technicianName.isEmpty ? "—" : record.technicianName
                    )
                }

                // ✅ Show DVIR traceability if this record was auto-created
                if !record.sourceReportNumber.isEmpty {
                    Section("Source") {
                        DetailRow(label: "DVIR Report", value: record.sourceReportNumber)
                        if !record.reportedBy.isEmpty {
                            DetailRow(label: "Reported By", value: record.reportedBy)
                        }
                    }
                }

                if !record.notes.isEmpty {
                    Section("Notes") {
                        Text(record.notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                if record.status != "Completed" {
                    Section {
                        Button {
                            showMarkComplete = true
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Mark as Completed").fontWeight(.semibold)
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
            .navigationTitle(record.maintenanceType)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { onDismiss(); dismiss() }
                }
            }
            .sheet(isPresented: $showMarkComplete) {
                MarkCompleteView(record: record) {
                    onDismiss()
                    dismiss()
                }
            }
        }
    }

    func statusColor(_ status: String) -> Color {
        if record.isOverdue && status != "Completed" { return .red }
        if record.isDueSoon && status != "Completed" { return .orange }
        switch status {
        case "Scheduled":   return .orange
        case "In Progress": return .blue
        case "Completed":   return .green
        default:            return .red
        }
    }

    func statusIcon(_ status: String) -> String {
        if record.isOverdue && status != "Completed" { return "exclamationmark.triangle.fill" }
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
    // ✅ Option to restore vehicle to Active on completion
    @State private var restoreVehicle = true

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

                // ✅ Restore vehicle toggle
                Section {
                    Toggle("Restore vehicle to Active", isOn: $restoreVehicle)
                } footer: {
                    Text("This will set Unit \(record.vehicleUnit) back to Active status.")
                        .font(.caption)
                }

                Section {
                    Button {
                        markComplete()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Confirm Complete").fontWeight(.semibold)
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
                    return
                }

                // ✅ Restore vehicle to Active if toggled on
                if self.restoreVehicle {
                    Firestore.firestore()
                        .collection("vehicles")
                        .whereField("unitNumber", isEqualTo: record.vehicleUnit)
                        .getDocuments { snapshot, _ in
                            snapshot?.documents.first?.reference.updateData([
                                "status": "Active",
                                "inspectionStatus": "Cleared",
                                "clearedAt": Timestamp()
                            ])
                        }
                }

                onComplete()
                dismiss()
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
    // ✅ Traceability fields
    var sourceReportNumber: String
    var reportedBy: String

    var isOverdue: Bool {
        status != "Completed" && dueDate < Date()
    }

    var daysOverdue: Int {
        guard isOverdue else { return 0 }
        return Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
    }

    // ✅ Due within 7 days but not yet overdue
    var isDueSoon: Bool {
        guard status != "Completed" && !isOverdue else { return false }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 999
        return days <= 7
    }

    var daysUntilDue: Int {
        guard isDueSoon else { return 0 }
        return Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
    }
}
