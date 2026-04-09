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
                        // ✅ Tappable row
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
                        // ✅ Tappable row
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
        // ✅ Employee detail sheet
        .sheet(item: $selectedEmployee) { emp in
            EmployeeDetailView(employee: emp) {
                fetchEmployees()
            }
        }
        // ✅ Vehicle detail sheet
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

    var body: some View {
        NavigationStack {
            List {
                Section("Employee Info") {
                    DetailRow(label: "Full Name", value: employee.name)
                    DetailRow(label: "Role", value: employee.role)
                    DetailRow(label: "Email", value: employee.email)
                    DetailRow(label: "Phone", value: employee.phone.isEmpty ? "—" : employee.phone)
                }
            }
            .navigationTitle(employee.name)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        onDismiss()
                        dismiss()
                    }
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

    var body: some View {
        NavigationStack {
            List {
                Section("Vehicle Info") {
                    DetailRow(label: "Unit Number", value: vehicle.unitNumber)
                    DetailRow(label: "Plate", value: vehicle.plate)
                    DetailRow(label: "Status", value: vehicle.status)
                }

                Section("Assignment") {
                    DetailRow(
                        label: "Assigned Driver",
                        value: vehicle.assignedDriverName.isEmpty
                            ? "Unassigned" : vehicle.assignedDriverName
                    )
                }
            }
            .navigationTitle("Unit \(vehicle.unitNumber)")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
    }
}

