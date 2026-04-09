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

    // ✅ Driver assignment
    @State private var drivers: [DriverOption] = []
    @State private var selectedDriverID = ""
    @State private var selectedDriverName = ""

    var onAdd: (Vehicle) -> Void

    var body: some View {
        NavigationStack {
            Form {

                // VEHICLE INFO
                Section("Vehicle Info") {
                    TextField("Unit Number", text: $unitNumber)
                    TextField("Plate", text: $plate)
                    Picker("Status", selection: $status) {
                        Text("Active").tag("Active")
                        Text("In Maintenance").tag("In Maintenance")
                        Text("Inactive").tag("Inactive")
                    }
                }

                // ASSIGN TO DRIVER
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

    // MARK: - Fetch Drivers
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

    // MARK: - Save Vehicle
    func saveVehicle() {
        let db = Firestore.firestore()

        // ✅ Find selected driver name for display
        if let driver = drivers.first(where: { $0.id == selectedDriverID }) {
            selectedDriverName = driver.name
        }

        // ✅ Step 1 — Save vehicle to Firestore
        let vehicleRef = db.collection("vehicles").document()
        vehicleRef.setData([
            "unitNumber": unitNumber,
            "plate": plate,
            "status": status,
            "assignedDriverID": selectedDriverID,
            "assignedDriverName": selectedDriverName,
            "createdAt": Timestamp()
        ])

        // ✅ Step 2 — If a driver was selected, update their user document
        if !selectedDriverID.isEmpty {
            db.collection("users").document(selectedDriverID).updateData([
                "vehicleUnit": unitNumber,
                "vehiclePlate": plate,
                "vehicleID": vehicleRef.documentID
            ]) { error in
                if let error = error {
                    print("Error assigning vehicle to driver: \(error.localizedDescription)")
                } else {
                    print("Vehicle assigned to driver successfully")
                }
            }
        }

        // ✅ Step 3 — Update local state and dismiss
        let newVehicle = Vehicle(
            unitNumber: unitNumber,
            plate: plate,
            status: status
        )
        onAdd(newVehicle)
        dismiss()
    }
}

// MARK: - Driver Option Model
struct DriverOption: Identifiable {
    let id: String
    let name: String
}

