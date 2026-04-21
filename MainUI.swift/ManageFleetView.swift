//
//  ManageFleet.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/4/26.
//
import SwiftUI
import FirebaseFirestore

struct ManageFleetView: View {

    // MARK: - State
    @State private var vehicles: [FleetVehicle] = []
    @State private var employees: [FleetEmployee] = []
    @State private var filterTab = "All"
    @State private var isLoading = true
    @State private var showAddVehicle = false
    @State private var showAddEmployee = false
    @State private var selectedVehicle: FleetVehicle? = nil
    @State private var selectedEmployee: FleetEmployee? = nil
    @State private var vehicleListener: ListenerRegistration? = nil
    @State private var employeeListener: ListenerRegistration? = nil

    let filters = ["All", "Vehicles", "Drivers", "Dispatchers"]

    // MARK: - Computed
    var filteredVehicles: [FleetVehicle] {
        guard filterTab == "All" || filterTab == "Vehicles" else { return [] }
        return vehicles.sorted { $0.unitNumber < $1.unitNumber }
    }

    var filteredEmployees: [FleetEmployee] {
        switch filterTab {
        case "Drivers":     return employees.filter { $0.role.lowercased() == "driver" }
        case "Dispatchers": return employees.filter { $0.role.lowercased() == "dispatcher" }
        case "All":         return employees
        default:            return []
        }
    }

    var activeVehicles: Int    { vehicles.filter { $0.status == "Active" }.count }
    var maintenanceVehicles: Int { vehicles.filter { $0.status == "In Maintenance" }.count }
    var activeDrivers: Int     { employees.filter { $0.role.lowercased() == "driver" }.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: - Stats Bar
                HStack(spacing: 0) {
                    FleetStatPill(value: "\(vehicles.count)", label: "Vehicles", color: .blue)
                    Divider().frame(height: 30)
                    FleetStatPill(value: "\(activeVehicles)", label: "Active", color: .green)
                    Divider().frame(height: 30)
                    FleetStatPill(value: "\(maintenanceVehicles)", label: "In Maint.", color: .orange)
                    Divider().frame(height: 30)
                    FleetStatPill(value: "\(activeDrivers)", label: "Drivers", color: .purple)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))

                Divider()

                // MARK: - Filter Tabs
                Picker("Filter", selection: $filterTab) {
                    ForEach(filters, id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color(.systemBackground))

                Divider()

                // MARK: - Content
                if isLoading {
                    Spacer()
                    ProgressView("Loading fleet...")
                    Spacer()
                } else {
                    List {

                        // VEHICLES SECTION
                        if filterTab == "All" || filterTab == "Vehicles" {
                            Section {
                                if filteredVehicles.isEmpty {
                                    ContentUnavailableView(
                                        "No Vehicles",
                                        systemImage: "truck.box",
                                        description: Text("Add a vehicle to get started.")
                                    )
                                } else {
                                    ForEach(filteredVehicles) { vehicle in
                                        Button {
                                            selectedVehicle = vehicle
                                        } label: {
                                            VehicleRowCard(vehicle: vehicle)
                                        }
                                    }
                                    .onDelete { indexSet in
                                        deleteVehicles(at: indexSet)
                                    }
                                }
                            } header: {
                                HStack {
                                    Label("Vehicles", systemImage: "truck.box.fill")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Button {
                                        showAddVehicle = true
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                    }
                                }
                            }
                        }

                        // EMPLOYEES SECTION
                        if filterTab != "Vehicles" {
                            Section {
                                if filteredEmployees.isEmpty {
                                    ContentUnavailableView(
                                        "No \(filterTab == "All" ? "Employees" : filterTab)",
                                        systemImage: "person.slash",
                                        description: Text("Add an employee to get started.")
                                    )
                                } else {
                                    ForEach(filteredEmployees) { employee in
                                        Button {
                                            selectedEmployee = employee
                                        } label: {
                                            EmployeeRowCard(employee: employee)
                                        }
                                    }
                                    .onDelete { indexSet in
                                        deleteEmployees(at: indexSet)
                                    }
                                }
                            } header: {
                                HStack {
                                    Label("Employees", systemImage: "person.3.fill")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Button {
                                        showAddEmployee = true
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.title3)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        // Listeners auto-refresh, but this gives manual pull-to-refresh feel
                        isLoading = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isLoading = false
                        }
                    }
                }
            }
            .navigationTitle("Manage Fleet")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showAddVehicle = true
                        } label: {
                            Label("Add Vehicle", systemImage: "truck.box.fill")
                        }
                        Button {
                            showAddEmployee = true
                        } label: {
                            Label("Add Employee", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear { startListeners() }
            .onDisappear { stopListeners() }

            // MARK: - Sheets
            .sheet(isPresented: $showAddVehicle) {
                AddVehicleView { _ in }
            }
            .sheet(isPresented: $showAddEmployee) {
                AddEmployeeView(onAdd: { _ in })
            }
            .sheet(item: $selectedVehicle) { vehicle in
                FleetVehicleDetailView(vehicle: vehicle)
            }
            .sheet(item: $selectedEmployee) { employee in
                FleetEmployeeDetailView(employee: employee)
            }
        }
    }

    // MARK: - Real-time Listeners
    func startListeners() {
        isLoading = true

        // ✅ Vehicles — live updates when inspection/report changes status
        vehicleListener = Firestore.firestore()
            .collection("vehicles")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    vehicles = docs.map { doc in
                        let d = doc.data()
                        return FleetVehicle(
                            id: doc.documentID,
                            unitNumber: d["unitNumber"] as? String ?? "",
                            plate: d["plate"] as? String ?? "",
                            status: d["status"] as? String ?? "Active",
                            assignedDriverName: d["assignedDriverName"] as? String ?? "",
                            lastInspectionDate: (d["lastInspectionDate"] as? Timestamp)?.dateValue(),
                            lastInspectedBy: d["lastInspectedBy"] as? String ?? "",
                            inspectionStatus: d["inspectionStatus"] as? String ?? ""
                        )
                    }
                    isLoading = false
                }
            }

        // ✅ Employees — drivers and dispatchers
        employeeListener = Firestore.firestore()
            .collection("users")
            .whereField("role", in: ["Driver", "Dispatcher"])
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    employees = docs.map { doc in
                        let d = doc.data()
                        return FleetEmployee(
                            id: doc.documentID,
                            name: d["name"] as? String ?? "",
                            email: d["email"] as? String ?? "",
                            role: d["role"] as? String ?? "",
                            vehicleUnit: d["vehicleUnit"] as? String ?? "",
                            phone: d["phone"] as? String ?? ""
                        )
                    }.filter { !$0.name.isEmpty }
                }
            }
    }

    func stopListeners() {
        vehicleListener?.remove()
        employeeListener?.remove()
        vehicleListener = nil
        employeeListener = nil
    }

    // MARK: - Delete
    func deleteVehicles(at indexSet: IndexSet) {
        let toDelete = indexSet.map { filteredVehicles[$0] }
        toDelete.forEach { vehicle in
            Firestore.firestore()
                .collection("vehicles")
                .document(vehicle.id)
                .delete()
        }
    }

    func deleteEmployees(at indexSet: IndexSet) {
        let toDelete = indexSet.map { filteredEmployees[$0] }
        toDelete.forEach { employee in
            Firestore.firestore()
                .collection("users")
                .document(employee.id)
                .delete()
        }
    }
}

// MARK: - Vehicle Row Card
struct VehicleRowCard: View {
    let vehicle: FleetVehicle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unit \(vehicle.unitNumber)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(vehicle.plate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // ✅ Status badge — updates live from Firestore
                Text(vehicle.status)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(vehicleStatusColor(vehicle.status).opacity(0.15))
                    .foregroundColor(vehicleStatusColor(vehicle.status))
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Divider()

            HStack(spacing: 16) {

                // Assigned driver
                if !vehicle.assignedDriverName.isEmpty {
                    Label(vehicle.assignedDriverName, systemImage: "person.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Label("No Driver", systemImage: "person.slash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Inspection status
                if !vehicle.inspectionStatus.isEmpty {
                    Label(vehicle.inspectionStatus, systemImage: "checkmark.shield")
                        .font(.caption)
                        .foregroundColor(inspectionStatusColor(vehicle.inspectionStatus))
                }
            }

            // Last inspection date
            if let date = vehicle.lastInspectionDate {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text("Last inspected: \(date.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                    if !vehicle.lastInspectedBy.isEmpty {
                        Text("by \(vehicle.lastInspectedBy)")
                            .font(.caption2)
                    }
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    func vehicleStatusColor(_ status: String) -> Color {
        switch status {
        case "Active":         return .green
        case "In Maintenance": return .orange
        case "Inactive":       return .gray
        default:               return .gray
        }
    }

    func inspectionStatusColor(_ status: String) -> Color {
        switch status {
        case "Passed":          return .green
        case "Failed":          return .red
        case "Needs Repair":    return .orange
        case "Accident Reported": return .red
        case "Cleared":         return .green
        default:                return .gray
        }
    }
}

// MARK: - Employee Row Card
struct EmployeeRowCard: View {
    let employee: FleetEmployee

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                // Role icon
                Image(systemName: employee.role.lowercased() == "driver" ? "steeringwheel" : "headphones")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(employee.role.lowercased() == "driver" ? Color.blue : Color.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(employee.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(employee.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(employee.role)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            employee.role.lowercased() == "driver"
                            ? Color.blue.opacity(0.12)
                            : Color.purple.opacity(0.12)
                        )
                        .foregroundColor(
                            employee.role.lowercased() == "driver" ? .blue : .purple
                        )
                        .clipShape(Capsule())

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }

            // Assigned vehicle for drivers
            if employee.role.lowercased() == "driver" {
                Divider()
                if !employee.vehicleUnit.isEmpty {
                    Label("Assigned: Unit \(employee.vehicleUnit)", systemImage: "truck.box.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("No vehicle assigned", systemImage: "truck.box")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Stat Pill
struct FleetStatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Models
struct FleetVehicle: Identifiable, Hashable {
    let id: String
    var unitNumber: String
    var plate: String
    var status: String
    var assignedDriverName: String
    var lastInspectionDate: Date?
    var lastInspectedBy: String
    var inspectionStatus: String
}

struct FleetEmployee: Identifiable, Hashable {
    let id: String
    var name: String
    var email: String
    var role: String
    var vehicleUnit: String
    var phone: String
}

// MARK: - Fleet Vehicle Detail View
struct FleetVehicleDetailView: View {

    @Environment(\.dismiss) var dismiss
    let vehicle: FleetVehicle

    // Editable fields
    @State private var unitNumber = ""
    @State private var plate = ""
    @State private var status = ""
    @State private var assignedDriver: FleetEmployee? = nil
    @State private var availableDrivers: [FleetEmployee] = []
    @State private var isEditMode = false
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var showUnassignConfirm = false

    let statuses = ["Active", "In Maintenance", "Inactive"]

    var body: some View {
        NavigationStack {
            List {

                // MARK: - Vehicle Info
                Section("Vehicle Info") {
                    if isEditMode {
                        HStack {
                            Text("Unit Number")
                                .foregroundColor(.secondary)
                                .frame(width: 110, alignment: .leading)
                            TextField("Unit Number", text: $unitNumber)
                        }
                        HStack {
                            Text("License Plate")
                                .foregroundColor(.secondary)
                                .frame(width: 110, alignment: .leading)
                            TextField("Plate", text: $plate)
                                .textInputAutocapitalization(.characters)
                        }
                    } else {
                        DetailRow(label: "Unit Number", value: unitNumber)
                        DetailRow(label: "License Plate", value: plate)
                    }
                }

                // MARK: - Status
                Section("Status") {
                    if isEditMode {
                        Picker("Status", selection: $status) {
                            ForEach(statuses, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        HStack {
                            Text("Status")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(status)
                                .fontWeight(.semibold)
                                .foregroundColor(vehicleStatusColor(status))
                        }
                    }
                }

                // MARK: - Driver Assignment
                Section("Driver Assignment") {
                    if isEditMode {
                        Picker("Assign Driver", selection: $assignedDriver) {
                            Text("Unassigned").tag(Optional<FleetEmployee>(nil))
                            ForEach(availableDrivers) { driver in
                                Text(driver.name).tag(Optional(driver))
                            }
                        }
                        .pickerStyle(.menu)

                        if assignedDriver != nil {
                            Button("Unassign Driver") {
                                showUnassignConfirm = true
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        if let driver = assignedDriver {
                            Label(driver.name, systemImage: "person.fill")
                                .foregroundColor(.blue)
                        } else {
                            Label("No driver assigned", systemImage: "person.slash")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // MARK: - Inspection (read-only)
                Section("Inspection") {
                    if !vehicle.inspectionStatus.isEmpty {
                        HStack {
                            Text("Status")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(vehicle.inspectionStatus)
                                .fontWeight(.semibold)
                                .foregroundColor(inspectionStatusColor(vehicle.inspectionStatus))
                        }
                    }
                    if let date = vehicle.lastInspectionDate {
                        DetailRow(
                            label: "Last Inspected",
                            value: date.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                    if !vehicle.lastInspectedBy.isEmpty {
                        DetailRow(label: "Inspected By", value: vehicle.lastInspectedBy)
                    }
                }

                // MARK: - Error
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                // MARK: - Save Button
                if isEditMode {
                    Section {
                        Button {
                            saveChanges()
                        } label: {
                            if isSaving {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save Changes").fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .navigationTitle("Unit \(vehicle.unitNumber)")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadFields()
                fetchDrivers()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditMode ? "Cancel" : "Done") {
                        if isEditMode {
                            // Reset on cancel
                            loadFields()
                            isEditMode = false
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditMode ? "Save" : "Edit") {
                        if isEditMode {
                            saveChanges()
                        } else {
                            isEditMode = true
                        }
                    }
                    .fontWeight(isEditMode ? .bold : .regular)
                }
            }
            .confirmationDialog(
                "Unassign Driver?",
                isPresented: $showUnassignConfirm,
                titleVisibility: .visible
            ) {
                Button("Yes, Unassign", role: .destructive) {
                    assignedDriver = nil
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    func loadFields() {
        unitNumber = vehicle.unitNumber
        plate = vehicle.plate
        status = vehicle.status
        // Pre-select assigned driver if any
        if !vehicle.assignedDriverName.isEmpty {
            assignedDriver = availableDrivers.first { $0.name == vehicle.assignedDriverName }
        }
    }

    func fetchDrivers() {
        Firestore.firestore()
            .collection("users")
            .whereField("role", isEqualTo: "Driver")
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    availableDrivers = docs.map { doc in
                        let d = doc.data()
                        return FleetEmployee(
                            id: doc.documentID,
                            name: d["name"] as? String ?? "",
                            email: d["email"] as? String ?? "",
                            role: "Driver",
                            vehicleUnit: d["vehicleUnit"] as? String ?? "",
                            phone: d["phone"] as? String ?? ""
                        )
                    }.filter { !$0.name.isEmpty }

                    // Now that drivers are loaded, match assigned driver
                    if !vehicle.assignedDriverName.isEmpty {
                        assignedDriver = availableDrivers.first {
                            $0.name == vehicle.assignedDriverName
                        }
                    }
                }
            }
    }

    func saveChanges() {
        guard !unitNumber.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Unit number cannot be empty."
            return
        }
        guard !plate.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "License plate cannot be empty."
            return
        }

        isSaving = true
        errorMessage = ""

        let driverName = assignedDriver?.name ?? ""
        let driverID = assignedDriver?.id ?? ""

        var updateData: [String: Any] = [
            "unitNumber": unitNumber.trimmingCharacters(in: .whitespaces),
            "plate": plate.trimmingCharacters(in: .whitespaces).uppercased(),
            "status": status,
            "assignedDriverName": driverName,
            "assignedDriverID": driverID
        ]

        // ✅ If status changed to Active, clear inspection flag
        if status == "Active" && vehicle.status != "Active" {
            updateData["inspectionStatus"] = "Cleared"
        }

        Firestore.firestore()
            .collection("vehicles")
            .document(vehicle.id)
            .updateData(updateData) { error in
                DispatchQueue.main.async {
                    isSaving = false
                    if let error = error {
                        errorMessage = error.localizedDescription
                        return
                    }

                    // ✅ Update driver's user doc with vehicle assignment
                    if let driver = assignedDriver {
                        Firestore.firestore()
                            .collection("users")
                            .document(driver.id)
                            .updateData([
                                "vehicleUnit": unitNumber,
                                "vehiclePlate": plate,
                                "vehicleID": vehicle.id
                            ])
                    }

                    // ✅ Clear vehicle from old driver if unassigned
                    if assignedDriver == nil && !vehicle.assignedDriverName.isEmpty {
                        Firestore.firestore()
                            .collection("users")
                            .whereField("name", isEqualTo: vehicle.assignedDriverName)
                            .getDocuments { snapshot, _ in
                                snapshot?.documents.first?.reference.updateData([
                                    "vehicleUnit": "",
                                    "vehiclePlate": "",
                                    "vehicleID": ""
                                ])
                            }
                    }

                    isEditMode = false
                    dismiss()
                }
            }
    }

    func vehicleStatusColor(_ status: String) -> Color {
        switch status {
        case "Active":         return .green
        case "In Maintenance": return .orange
        case "Inactive":       return .gray
        default:               return .gray
        }
    }

    func inspectionStatusColor(_ status: String) -> Color {
        switch status {
        case "Passed":            return .green
        case "Failed":            return .red
        case "Needs Repair":      return .orange
        case "Accident Reported": return .red
        case "Cleared":           return .green
        default:                  return .gray
        }
    }
}

// MARK: - Fleet Employee Detail View
struct FleetEmployeeDetailView: View {

    @Environment(\.dismiss) var dismiss
    let employee: FleetEmployee

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var role = ""
    @State private var selectedVehicle: FleetVehicle? = nil
    @State private var availableVehicles: [FleetVehicle] = []
    @State private var isEditMode = false
    @State private var isSaving = false
    @State private var errorMessage = ""

    let roles = ["Driver", "Dispatcher"]

    var body: some View {
        NavigationStack {
            List {

                // MARK: - Employee Info
                Section("Employee Info") {
                    if isEditMode {
                        HStack {
                            Text("Name")
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            TextField("Full Name", text: $name)
                                .textInputAutocapitalization(.words)
                        }
                        HStack {
                            Text("Phone")
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            TextField("Phone Number", text: $phone)
                                .keyboardType(.phonePad)
                        }
                    } else {
                        DetailRow(label: "Name", value: name)
                        DetailRow(label: "Email", value: email)
                        if !phone.isEmpty {
                            DetailRow(label: "Phone", value: phone)
                        }
                    }
                }

                // MARK: - Role
                Section("Role") {
                    if isEditMode {
                        Picker("Role", selection: $role) {
                            ForEach(roles, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        HStack {
                            Image(systemName: role.lowercased() == "driver"
                                  ? "steeringwheel" : "headphones")
                                .foregroundColor(role.lowercased() == "driver" ? .blue : .purple)
                            Text(role)
                                .fontWeight(.semibold)
                                .foregroundColor(role.lowercased() == "driver" ? .blue : .purple)
                        }
                    }
                }

                // MARK: - Vehicle Assignment (Drivers only)
                if role.lowercased() == "driver" {
                    Section("Vehicle Assignment") {
                        if isEditMode {
                            Picker("Assign Vehicle", selection: $selectedVehicle) {
                                Text("Unassigned").tag(Optional<FleetVehicle>(nil))
                                ForEach(availableVehicles) { vehicle in
                                    Text("Unit \(vehicle.unitNumber) — \(vehicle.plate)")
                                        .tag(Optional(vehicle))
                                }
                            }
                            .pickerStyle(.menu)
                        } else {
                            if let vehicle = selectedVehicle {
                                Label(
                                    "Unit \(vehicle.unitNumber) — \(vehicle.plate)",
                                    systemImage: "truck.box.fill"
                                )
                                .foregroundColor(.green)
                            } else {
                                Label("No vehicle assigned", systemImage: "truck.box")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // MARK: - Error
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                // MARK: - Save Button
                if isEditMode {
                    Section {
                        Button {
                            saveChanges()
                        } label: {
                            if isSaving {
                                ProgressView().frame(maxWidth: .infinity)
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save Changes").fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .navigationTitle(employee.name)
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadFields()
                fetchVehicles()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditMode ? "Cancel" : "Done") {
                        if isEditMode {
                            loadFields()
                            isEditMode = false
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditMode ? "Save" : "Edit") {
                        if isEditMode {
                            saveChanges()
                        } else {
                            isEditMode = true
                        }
                    }
                    .fontWeight(isEditMode ? .bold : .regular)
                }
            }
        }
    }

    func loadFields() {
        name = employee.name
        email = employee.email
        phone = employee.phone
        role = employee.role
        if !employee.vehicleUnit.isEmpty {
            selectedVehicle = availableVehicles.first { $0.unitNumber == employee.vehicleUnit }
        }
    }

    func fetchVehicles() {
        Firestore.firestore()
            .collection("vehicles")
            .whereField("status", isEqualTo: "Active")
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    availableVehicles = docs.map { doc in
                        let d = doc.data()
                        return FleetVehicle(
                            id: doc.documentID,
                            unitNumber: d["unitNumber"] as? String ?? "",
                            plate: d["plate"] as? String ?? "",
                            status: d["status"] as? String ?? "Active",
                            assignedDriverName: d["assignedDriverName"] as? String ?? "",
                            lastInspectionDate: (d["lastInspectionDate"] as? Timestamp)?.dateValue(),
                            lastInspectedBy: d["lastInspectedBy"] as? String ?? "",
                            inspectionStatus: d["inspectionStatus"] as? String ?? ""
                        )
                    }.filter { !$0.unitNumber.isEmpty }

                    // Match assigned vehicle
                    if !employee.vehicleUnit.isEmpty {
                        selectedVehicle = availableVehicles.first {
                            $0.unitNumber == employee.vehicleUnit
                        }
                    }
                }
            }
    }

    func saveChanges() {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Name cannot be empty."
            return
        }

        isSaving = true
        errorMessage = ""

        let vehicleUnit = selectedVehicle?.unitNumber ?? ""
        let vehiclePlate = selectedVehicle?.plate ?? ""
        let vehicleID = selectedVehicle?.id ?? ""

        Firestore.firestore()
            .collection("users")
            .document(employee.id)
            .updateData([
                "name": name.trimmingCharacters(in: .whitespaces),
                "phone": phone,
                "role": role,
                "vehicleUnit": vehicleUnit,
                "vehiclePlate": vehiclePlate,
                "vehicleID": vehicleID
            ]) { error in
                DispatchQueue.main.async {
                    isSaving = false
                    if let error = error {
                        errorMessage = error.localizedDescription
                        return
                    }

                    // ✅ Update vehicle's assigned driver info
                    if let vehicle = selectedVehicle {
                        Firestore.firestore()
                            .collection("vehicles")
                            .document(vehicle.id)
                            .updateData([
                                "assignedDriverName": name,
                                "assignedDriverID": employee.id
                            ])
                    }

                    // ✅ Clear old vehicle assignment if vehicle was changed
                    if selectedVehicle == nil && !employee.vehicleUnit.isEmpty {
                        Firestore.firestore()
                            .collection("vehicles")
                            .whereField("unitNumber", isEqualTo: employee.vehicleUnit)
                            .getDocuments { snapshot, _ in
                                snapshot?.documents.first?.reference.updateData([
                                    "assignedDriverName": "",
                                    "assignedDriverID": ""
                                ])
                            }
                    }

                    isEditMode = false
                    dismiss()
                }
            }
    }
}
