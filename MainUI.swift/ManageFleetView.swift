//
//  ManageFleet.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/21/26.
//
import SwiftUI

struct ManageFleetView: View {

    @State private var vehicles: [Vehicle] = []
    @State private var drivers: [Driver] = []

    @State private var showAddVehicle = false
    @State private var showAddDriver = false
    
        

    var body: some View {
        NavigationStack {

            List {

                Section("Vehicles") {

                    ForEach(vehicles) { v in
                        VStack(alignment: .leading) {
                            Text(v.unitNumber)
                                .font(.headline)

                            Text("\(v.plate) • \(v.status)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        vehicles.remove(atOffsets: indexSet)
                    }

                    Button("Add Vehicle") {
                        showAddVehicle = true
                    }
                }

                Section("Drivers") {

                    ForEach(drivers) { d in
                        VStack(alignment: .leading) {
                            Text(d.name)
                                .font(.headline)

                            Text("\(d.email) • \(d.status)")
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete { indexSet in
                        drivers.remove(atOffsets: indexSet)
                    }

                    Button("Add Driver") {
                        showAddDriver = true
                    }
                }
            }
            .navigationTitle("Manage Fleet")
            .sheet(isPresented: $showAddVehicle) {

                NavigationStack {
                    AddVehicleView { newVehicle in
                        vehicles.append(newVehicle)
                    }
                }

            }
            .sheet(isPresented: $showAddDriver) {
                AddDriverView { newDriver in
                    drivers.append(newDriver)
                }
            }
        }
    }
}
