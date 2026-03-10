//
//  AddVehicleView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/7/26.
//


import SwiftUI

struct AddVehicleView: View {

    @Environment(\.dismiss) var dismiss

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

                        let vehicle = Vehicle(
                            unitNumber: unitNumber,
                            plate: plate,
                            status: status
                        )

                        onAdd(vehicle)
                        dismiss()
                    }
                }
            }
        }
    }
}
