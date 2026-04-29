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
    @State private var drivers: [DriverOption] = []
    @State private var selectedDriverID = ""
    @State private var selectedDriverName = ""
    @State private var errorMessage = ""
    @State private var isSaving = false

    var onAdd: (Vehicle) -> Void

    var body: some View {
        NavigationStack {
            Form {

                Section("Vehicle Info") {
                    TextField("Unit Number", text: $unitNumber)
                    TextField("Plate", text: $plate)
                    Picker("Status", selection: $status) {
                        Text("Active").tag("Active")
                        Text("In Maintenance").tag("In Maintenance")
                        Text("Inactive").tag("Inactive")
                    }
                }

                Section("Assign to Driver") {
                    if drivers.isEmpty {
                        Text("No drivers available.")
                            .foregroundColor(.gray)
                    } else {
                        Picker("Select Driver", selection: $selectedDriverID) {
                            Text("Unassigned").tag("")
                            ForEach(drivers) { driver in
                                Text(driver.name).tag(driver.id)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedDriverID) { id in
                            selectedDriverName = drivers.first { $0.id == id }?.name ?? ""
                        }

                        if !selectedDriverID.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Will be assigned to \(selectedDriverName)")
                                    .font(.caption).foregroundColor(.green)
                            }
                        }
                    }
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red).font(.caption)
                    }
                }

                if isSaving {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Saving...")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Add Vehicle")
            .onAppear { fetchDrivers() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { saveVehicle() }
                        .disabled(unitNumber.isEmpty || plate.isEmpty || isSaving)
                }
            }
        }
    }

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
                            name: doc.data()["name"] as? String ?? "Unknown"
                        )
                    }
                }
            }
    }

    func saveVehicle() {
        errorMessage = ""
        isSaving = true

        let db = Firestore.firestore()
        let trimmedUnit = unitNumber.trimmingCharacters(in: .whitespaces)
        let trimmedPlate = plate.uppercased().trimmingCharacters(in: .whitespaces)

        //  Step 1 — Duplicate check
        db.collection("vehicles").getDocuments { snapshot, _ in
            guard let docs = snapshot?.documents else {
                DispatchQueue.main.async { isSaving = false }
                return
            }

            let existingUnits  = docs.compactMap { $0.data()["unitNumber"] as? String }
            let existingPlates = docs.compactMap { $0.data()["plate"] as? String }

            if existingUnits.contains(where: { $0.lowercased() == trimmedUnit.lowercased() }) {
                DispatchQueue.main.async {
                    errorMessage = "Unit number \(trimmedUnit) already exists."
                    isSaving = false
                }
                return
            }
            if existingPlates.contains(where: { $0.lowercased() == trimmedPlate.lowercased() }) {
                DispatchQueue.main.async {
                    errorMessage = "Plate \(trimmedPlate) already exists."
                    isSaving = false
                }
                return
            }

            //  Step 2 — Create the vehicle document
            let vehicleRef = db.collection("vehicles").document()
            vehicleRef.setData([
                "unitNumber": trimmedUnit,
                "plate": trimmedPlate,
                "status": status,
                "assignedDriverID": selectedDriverID,
                "assignedDriverName": selectedDriverName,
                "createdAt": Timestamp()
            ])

            //  Step 3 — If a driver was selected, enforce one-to-one
            if !selectedDriverID.isEmpty {
                enforceOneToOne(
                    db: db,
                    newDriverID: selectedDriverID,
                    newDriverName: selectedDriverName,
                    newVehicleDocID: vehicleRef.documentID,
                    newUnitNumber: trimmedUnit,
                    newPlate: trimmedPlate
                )
            }

            DispatchQueue.main.async {
                isSaving = false
                let newVehicle = Vehicle(
                    unitNumber: trimmedUnit,
                    plate: trimmedPlate,
                    status: status,
                    assignedDriverID: selectedDriverID,
                    assignedDriverName: selectedDriverName
                )
                onAdd(newVehicle)
                dismiss()
            }
        }
    }

    // MARK: - One-to-One Enforcement
    //  When assigning a driver to a new vehicle:
    //    - Clear the driver's old vehicle (if any)
    //    - Update the driver's user doc with the new vehicle
    func enforceOneToOne(
        db: Firestore,
        newDriverID: String,
        newDriverName: String,
        newVehicleDocID: String,
        newUnitNumber: String,
        newPlate: String
    ) {
        // Check if driver already has a vehicle assigned — clear it
        db.collection("users").document(newDriverID).getDocument { snapshot, _ in
            if let data = snapshot?.data(),
               let oldUnit = data["vehicleUnit"] as? String, !oldUnit.isEmpty {
                // Find and clear the old vehicle's driver assignment
                db.collection("vehicles")
                    .whereField("unitNumber", isEqualTo: oldUnit)
                    .getDocuments { snap, _ in
                        snap?.documents.first?.reference.updateData([
                            "assignedDriverID": "",
                            "assignedDriverName": ""
                        ])
                    }
            }

            // Update driver's user doc with new vehicle
            db.collection("users").document(newDriverID).updateData([
                "vehicleUnit": newUnitNumber,
                "vehiclePlate": newPlate,
                "vehicleID": newVehicleDocID
            ])
        }
    }
}
