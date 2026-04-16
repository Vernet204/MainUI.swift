//
//  ManageFleet.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/4/26.
//
import SwiftUI
import FirebaseFirestore

struct ManageFleetView: View {

    @State private var employees: [EmployeeDetail] = []
    @State private var vehicles: [Vehicle] = []
    @State private var showAddEmployee = false
    @State private var showAddVehicle = false
    @State private var isLoading = true
    @State private var selectedEmployee: EmployeeDetail? = nil
    @State private var selectedVehicle: Vehicle? = nil

    var body: some View {
        List {

            // MARK: - Employees
            Section("Employees") {
                if isLoading {
                    ProgressView("Loading...")
                } else if employees.isEmpty {
                    Text("No employees found.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(employees) { emp in
                        Button {
                            selectedEmployee = emp
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(emp.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(emp.role)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(emp.email)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { deleteEmployees(at: $0) }
                }

                Button {
                    showAddEmployee = true
                } label: {
                    Label("Add New Employee", systemImage: "person.badge.plus")
                }
            }

            // MARK: - Vehicles
            Section("Vehicles") {
                if isLoading {
                    ProgressView("Loading...")
                } else if vehicles.isEmpty {
                    Text("No vehicles found.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(vehicles) { v in
                        Button {
                            selectedVehicle = v
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Unit: \(v.unitNumber)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Plate: \(v.plate)")
                                    .font(.caption)
                                HStack {
                                    Text("Status: \(v.status)")
                                        .font(.caption)
                                        .foregroundColor(v.status == "Active" ? .green : .orange)
                                    Spacer()
                                    if !v.assignedDriverName.isEmpty {
                                        Label(v.assignedDriverName, systemImage: "person.fill")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    } else {
                                        Text("Unassigned")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { deleteVehicles(at: $0) }
                }

                Button {
                    showAddVehicle = true
                } label: {
                    Label("Add New Vehicle", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Manage Fleet")
        .onAppear {
            fetchEmployees()
            fetchVehicles()
        }
        .sheet(isPresented: $showAddEmployee, onDismiss: fetchEmployees) {
            AddEmployeeView { emp in
                employees.append(EmployeeDetail(
                    id: UUID().uuidString,
                    name: emp.name,
                    role: emp.role,
                    email: emp.Email,
                    phone: ""
                ))
            }
        }
        .sheet(isPresented: $showAddVehicle, onDismiss: fetchVehicles) {
            AddVehicleView { v in vehicles.append(v) }
        }
        .sheet(item: $selectedEmployee) { emp in
            EmployeeDetailView(employee: emp) {
                fetchEmployees()
            }
        }
        .sheet(item: $selectedVehicle) { vehicle in
            VehicleDetailView(vehicle: vehicle) {
                fetchVehicles()
            }
        }
    }

    // MARK: - Fetch Employees
    func fetchEmployees() {
        Firestore.firestore()
            .collection("users")
            .whereField("role", in: ["Driver", "Dispatcher"])
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    employees = docs.map { doc in
                        let data = doc.data()
                        return EmployeeDetail(
                            id: doc.documentID,
                            name: data["name"] as? String ?? "",
                            role: data["role"] as? String ?? "",
                            email: data["email"] as? String ?? "",
                            phone: data["phone"] as? String ?? ""
                        )
                    }
                    isLoading = false
                }
            }
    }

    // MARK: - Fetch Vehicles
    func fetchVehicles() {
        Firestore.firestore()
            .collection("vehicles")
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    vehicles = docs.map { doc in
                        let data = doc.data()
                        return Vehicle(
                            unitNumber: data["unitNumber"] as? String ?? "",
                            plate: data["plate"] as? String ?? "",
                            status: data["status"] as? String ?? "",
                            assignedDriverID: data["assignedDriverID"] as? String ?? "",
                            assignedDriverName: data["assignedDriverName"] as? String ?? ""
                        )
                    }
                    isLoading = false
                }
            }
    }

    // MARK: - Delete Employee
    func deleteEmployees(at indexSet: IndexSet) {
        indexSet.forEach { index in
            let emp = employees[index]
            Firestore.firestore().collection("users").document(emp.id).delete()
        }
        employees.remove(atOffsets: indexSet)
    }

    // MARK: - Delete Vehicle
    func deleteVehicles(at indexSet: IndexSet) {
        let db = Firestore.firestore()
        indexSet.forEach { index in
            let vehicle = vehicles[index]
            db.collection("vehicles")
                .whereField("unitNumber", isEqualTo: vehicle.unitNumber)
                .getDocuments { snapshot, _ in
                    snapshot?.documents.forEach { $0.reference.delete() }
                }
        }
        vehicles.remove(atOffsets: indexSet)
    }
}

// MARK: - Employee Detail Model
struct EmployeeDetail: Identifiable {
    let id: String
    var name: String
    var role: String
    var email: String
    var phone: String
}

// MARK: - Employee Detail View
struct EmployeeDetailView: View {

    @Environment(\.dismiss) var dismiss
    let employee: EmployeeDetail
    var onDismiss: () -> Void

    @State private var isEditing = false
    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var role = "Driver"
    @State private var isSaving = false
    @State private var errorMessage = ""

    let roles = ["Driver", "Dispatcher"]

    var body: some View {
        NavigationStack {
            List {
                if isEditing {

                    // EDIT MODE
                    Section("Employee Info") {
                        TextField("Full Name", text: $name)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        TextField("Phone", text: $phone)
                            .keyboardType(.phonePad)
                    }

                    Section("Role") {
                        Picker("Role", selection: $role) {
                            ForEach(roles, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    if !errorMessage.isEmpty {
                        Section {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }

                    Section {
                        Button {
                            saveChanges()
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save Changes")
                                        .fontWeight(.semibold)
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

                } else {

                    // VIEW MODE
                    Section("Employee Info") {
                        DetailRow(label: "Full Name", value: name)
                        DetailRow(label: "Role", value: role)
                        DetailRow(label: "Email", value: email.isEmpty ? "—" : email)
                        DetailRow(label: "Phone", value: phone.isEmpty ? "—" : phone)
                    }
                }
            }
            .navigationTitle(name.isEmpty ? "Employee" : name)
            .onAppear { loadFields() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditing ? "Cancel" : "Close") {
                        if isEditing {
                            isEditing = false
                            loadFields() // ✅ Reset unsaved changes
                        } else {
                            onDismiss()
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            saveChanges()
                        } else {
                            isEditing = true
                        }
                    }
                    .fontWeight(isEditing ? .bold : .regular)
                }
            }
        }
    }

    // MARK: - Load Fields
    func loadFields() {
        name = employee.name
        email = employee.email
        phone = employee.phone
        role = employee.role
    }

    // MARK: - Save Changes
    func saveChanges() {
        guard !name.isEmpty else {
            errorMessage = "Name cannot be empty."
            return
        }

        isSaving = true
        errorMessage = ""

        Firestore.firestore()
            .collection("users")
            .document(employee.id)
            .updateData([
                "name": name,
                "email": email,
                "phone": phone,
                "role": role
            ]) { error in
                DispatchQueue.main.async {
                    isSaving = false
                    if let error = error {
                        errorMessage = error.localizedDescription
                        print("❌ Error updating employee: \(error.localizedDescription)")
                    } else {
                        isEditing = false
                        onDismiss()
                        dismiss()
                    }
                }
            }
    }
}

// MARK: - Vehicle Detail View
struct VehicleDetailView: View {

    @Environment(\.dismiss) var dismiss
    let vehicle: Vehicle
    var onDismiss: () -> Void

    @State private var isEditing = false
    @State private var unitNumber = ""
    @State private var plate = ""
    @State private var status = "Active"
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var drivers: [DriverOption] = []
    @State private var assignedDriverID = ""
    @State private var assignedDriverName = ""

    let statuses = ["Active", "In Maintenance", "Inactive"]

    var body: some View {
        NavigationStack {
            List {
                if isEditing {

                    // EDIT MODE
                    Section("Vehicle Info") {
                        TextField("Unit Number", text: $unitNumber)
                        TextField("Plate", text: $plate)
                        Picker("Status", selection: $status) {
                            ForEach(statuses, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                    }

                    Section("Assign Driver") {
                        Picker("Select Driver", selection: $assignedDriverID) {
                            Text("Unassigned").tag("")
                            ForEach(drivers) { driver in
                                Text(driver.name).tag(driver.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: assignedDriverID) { id in
                            assignedDriverName = drivers.first(where: {
                                $0.id == id
                            })?.name ?? ""
                        }
                    }

                    if !errorMessage.isEmpty {
                        Section {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }

                    Section {
                        Button {
                            saveChanges()
                        } label: {
                            if isSaving {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save Changes")
                                        .fontWeight(.semibold)
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

                } else {

                    // VIEW MODE
                    Section("Vehicle Info") {
                        DetailRow(label: "Unit Number", value: unitNumber)
                        DetailRow(label: "Plate", value: plate)
                        DetailRow(label: "Status", value: status)
                    }

                    Section("Assignment") {
                        DetailRow(
                            label: "Assigned Driver",
                            value: assignedDriverName.isEmpty
                                ? "Unassigned" : assignedDriverName
                        )
                    }
                }
            }
            .navigationTitle("Unit \(unitNumber)")
            .onAppear {
                loadFields()
                fetchDrivers()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditing ? "Cancel" : "Close") {
                        if isEditing {
                            isEditing = false
                            loadFields() // ✅ Reset unsaved changes
                        } else {
                            onDismiss()
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            saveChanges()
                        } else {
                            isEditing = true
                        }
                    }
                    .fontWeight(isEditing ? .bold : .regular)
                }
            }
        }
    }

    // MARK: - Load Fields
    func loadFields() {
        unitNumber = vehicle.unitNumber
        plate = vehicle.plate
        status = vehicle.status
        assignedDriverName = vehicle.assignedDriverName
        assignedDriverID = vehicle.assignedDriverID
    }

    // MARK: - Fetch Drivers
    func fetchDrivers() {
        Firestore.firestore()
            .collection("users")
            .whereField("role", isEqualTo: "Driver")
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    drivers = docs.map { doc in
                        DriverOption(
                            id: doc.documentID,
                            name: doc.data()["name"] as? String ?? ""
                        )
                    }
                }
            }
    }

    // MARK: - Save Changes
    func saveChanges() {
        guard !unitNumber.isEmpty else {
            errorMessage = "Unit number cannot be empty."
            return
        }

        isSaving = true
        errorMessage = ""

        let db = Firestore.firestore()

        // ✅ Step 1 — Find and update vehicle document
        db.collection("vehicles")
            .whereField("unitNumber", isEqualTo: vehicle.unitNumber)
            .getDocuments { snapshot, error in
                guard let doc = snapshot?.documents.first else {
                    DispatchQueue.main.async {
                        isSaving = false
                        errorMessage = "Vehicle not found."
                    }
                    return
                }

                // ✅ Update vehicle fields
                doc.reference.updateData([
                    "unitNumber": unitNumber,
                    "plate": plate,
                    "status": status,
                    "assignedDriverID": assignedDriverID,
                    "assignedDriverName": assignedDriverName
                ])

                // ✅ Step 2 — Assign vehicle to new driver
                if !assignedDriverID.isEmpty {
                    db.collection("users")
                        .document(assignedDriverID)
                        .updateData([
                            "vehicleUnit": unitNumber,
                            "vehiclePlate": plate
                        ])
                }

                // ✅ Step 3 — Remove vehicle from old driver if changed
                if vehicle.assignedDriverID != assignedDriverID,
                   !vehicle.assignedDriverID.isEmpty {
                    db.collection("users")
                        .document(vehicle.assignedDriverID)
                        .updateData([
                            "vehicleUnit": "",
                            "vehiclePlate": "",
                            "vehicleID": ""
                        ])
                }

                DispatchQueue.main.async {
                    isSaving = false
                    isEditing = false
                    onDismiss()
                    dismiss()
                }
            }
    }
}
