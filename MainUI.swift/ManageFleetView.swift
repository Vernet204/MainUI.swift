//
//  ManageFleet.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/4/26.
//
import SwiftUI

struct ManageFleetView: View {

    @State private var employees: [Employee] = []
    @State private var vehicles: [Vehicle] = []
    @State private var showAddEmployee = false
    @State private var showAddVehicle = false

    var body: some View {
        List {

            // MARK: - Employees
            Section("Employees") {
                ForEach(employees) { emp in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(emp.name)
                            .font(.headline)
                        Text(emp.role)
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(emp.Email)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { employees.remove(atOffsets: $0) }

                Button {
                    showAddEmployee = true
                } label: {
                    Label("Add New Employee", systemImage: "person.badge.plus")
                }
            }

            // MARK: - Vehicles
            Section("Vehicles") {
                ForEach(vehicles) { v in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unit: \(v.unitNumber)")
                            .font(.headline)
                        Text("Plate: \(v.plate)")
                            .font(.caption)
                        Text("Status: \(v.status)")
                            .font(.caption)
                            .foregroundColor(v.status == "Active" ? .green : .orange)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { vehicles.remove(atOffsets: $0) }

                Button {
                    showAddVehicle = true
                } label: {
                    Label("Add New Vehicle", systemImage: "plus.circle")
                }
            }
        }
        .navigationTitle("Manage Fleet")
        .sheet(isPresented: $showAddEmployee) {
            AddEmployeeView { emp in employees.append(emp) }
        }
        .sheet(isPresented: $showAddVehicle) {
            NavigationStack {
                AddVehicleView { v in vehicles.append(v) }
            }
        }
    }
}
