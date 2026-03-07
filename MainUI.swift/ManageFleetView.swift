//
//  ManageFleet.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/21/26.
//
import SwiftUI


struct ManageFleetView: View {
    @State private var vehicles: [Vehicle] = [
        .init(unitNumber: "Truck 101", vin: "0123456789",make: "Dodge", model: "Ram", year: "2020", plateNumber: "FL-ABC123", inspectionStatus:"Active", insuranceStatus: "Active")
    ]
    @State private var drivers: [Driver] = [
        .init(name: "John Driver", assignedVehicleNumber: "driver@test.com", status: "Active", Email: "John321@gmail.com")
    ]

    @State private var showAddVehicle = false
    @State private var showAddDriver = false

    var body: some View {
        List {
            Section("Vehicles") {
                ForEach($vehicles) { v in
                    VStack(alignment: .leading) {
                        Text("\(v.plate) • \(v.status)").foregroundStyle(.secondary)
                    }
                }
                .onDelete { vehicles.remove(atOffsets: $0) }

                Button("Add Vehicle") { showAddVehicle = true }
            }

            Section("Drivers") {
                ForEach(drivers) { d in
                    VStack(alignment: .leading) {
                        Text(d.name).font(.headline)
                        Text("\(d.email) • \(d.status)").foregroundStyle(.secondary)
                    }
                }
                .onDelete { drivers.remove(atOffsets: $0) }

                Button("Add Driver") { showAddDriver = true }
            }
        }
        .navigationTitle("Manage Fleet")
        .sheet(isPresented: $showAddVehicle) {
            AddVehicleView { newVehicle in
                vehicles.append(newVehicle)
            }
        }
        .sheet(isPresented: $showAddDriver) {
            AddDriverView { newDriver in
                drivers.append(newDriver)
            }
        }
    }
}

struct AddVehicleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var unitNumber = ""
    @State private var plate = ""
    @State private var status = "Active"

    var onAdd: (Vehicle) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Unit Number", text: $unitNumber)
                TextField("Plate", text: $plate)
                Picker("Status", selection: $status) {
                    Text("Active").tag("Active")
                    Text("In Maintenance").tag("In Maintenance")
                    Text("Inactive").tag("Inactive")
                }
            }
            .navigationTitle("Add Vehicle")
                .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(
                            Vehicle(
                                unitNumber: unitNumber,
                                plate: plate,
                                status: status
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}

struct AddDriverView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var status = "Active"

    var onAdd: (Driver) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.none)
                    .autocorrectionDisabled()

                Picker("Status", selection: $status) {
                    Text("Active").tag("Active")
                    Text("Inactive").tag("Inactive")
                }
            }
            .navigationTitle("Add Driver")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(.init(name: name, assignedVehicleNumber: email, status: status, Email: email))
                        dismiss()
                    }
                    .disabled(name.isEmpty || email.isEmpty)
                }
            }
        }
    }
}
