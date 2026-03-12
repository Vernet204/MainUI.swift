//
//  AddVehicleView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/7/26.
//


import SwiftUI
import FirebaseFirestore

struct AddVehicleView: View {

    @Environment(\.dismiss) var dismiss

    @State private var unitNumber = ""
    @State private var plate = ""
    @State private var status = "Active"

    var onAdd: (Vehicle) -> Void

    var body: some View {

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

                    saveVehicleToFirebase(vehicle)

                    onAdd(vehicle)

                    dismiss()
                }
            }
        }
    }


    // MARK: - Firebase Save
    func saveVehicleToFirebase(_ vehicle: Vehicle) {

        Firestore.firestore()
            .collection("vehicles")
            .addDocument(data: [

                "unitNumber": vehicle.unitNumber,
                "plate": vehicle.plate,
                "status": vehicle.status,
                "createdAt": Timestamp()

            ]) { error in

                if let error = error {
                    print("Error saving vehicle: \(error.localizedDescription)")
                } else {
                    print("Vehicle saved successfully")
                }
            }
    }
}

