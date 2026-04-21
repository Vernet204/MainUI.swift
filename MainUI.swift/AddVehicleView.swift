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
    @State private var errorMessage = ""  // ✅ was missing

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
                            selectedDriverName = drivers.first(where: {
                                $0.id == id
                            })?.name ?? ""
                        }

                        if !selectedDriverID.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Will be assigned to \(selectedDriverName)")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                // ✅ Error message display
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
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
                        .disabled(unitNumber.isEmpty || plate.isEmpty)
                }
            }
        }
    }

    func fetchDrivers() {
        Firestore.firestore()
            .collection("users")
            .whereField("role", isEqualTo: "Driver")
            .getDocuments { snapshot, error in
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

        Firestore.firestore()
            .collection("vehicles")
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else { return }

                let existingUnits = docs.compactMap { $0.data()["unitNumber"] as? String }
                let existingPlates = docs.compactMap { $0.data()["plate"] as? String }

                if existingUnits.contains(where: {
                    $0.lowercased() == unitNumber.lowercased().trimmingCharacters(in: .whitespaces)
                }) {
                    DispatchQueue.main.async {
                        errorMessage = "A vehicle with unit number \(unitNumber) already exists."
                    }
                    return
                }

                if existingPlates.contains(where: {
                    $0.lowercased() == plate.lowercased().trimmingCharacters(in: .whitespaces)
                }) {
                    DispatchQueue.main.async {
                        errorMessage = "A vehicle with plate \(plate) already exists."
                    }
                    return
                }

                let db = Firestore.firestore()
                let vehicleRef = db.collection("vehicles").document()

                vehicleRef.setData([
                    "unitNumber": unitNumber.trimmingCharacters(in: .whitespaces),
                    "plate": plate.uppercased().trimmingCharacters(in: .whitespaces),
                    "status": status,
                    "assignedDriverID": selectedDriverID,
                    "assignedDriverName": selectedDriverName,
                    "createdAt": Timestamp()
                ])

                if !selectedDriverID.isEmpty {
                    db.collection("users").document(selectedDriverID).updateData([
                        "vehicleUnit": unitNumber,
                        "vehiclePlate": plate,
                        "vehicleID": vehicleRef.documentID
                    ])
                }

                DispatchQueue.main.async {
                    let newVehicle = Vehicle(
                        unitNumber: unitNumber,
                        plate: plate,
                        status: status,
                        assignedDriverID: selectedDriverID,
                        assignedDriverName: selectedDriverName
                    )
                    onAdd(newVehicle)
                    dismiss()
                }
            }
    }
}

// MARK: - Driver Option Model

