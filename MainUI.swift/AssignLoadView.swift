//
//  AssignLoadView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/10/26.
//

import SwiftUI
import FirebaseFirestore

struct AssignLoadView: View {

    @State private var loads: [LoadInfo] = []
    @State private var drivers: [DriverInfo] = []
    @State private var selectedLoad: LoadInfo? = nil
    @State private var selectedDriver: DriverInfo? = nil
    @State private var showConfirmation = false

    var body: some View {
        List {

            // LOADS SECTION
            Section("Select Load") {
                ForEach(loads) { load in
                    Button {
                        selectedLoad = load
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Load ID: \(load.loadID)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedLoad?.id == load.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            Text("\(load.pickupLocation) → \(load.deliveryLocation)")
                                .font(.subheadline).foregroundColor(.secondary)
                            Text("Pickup: \(load.pickupDate)")
                                .font(.caption).foregroundColor(.secondary)
                            Text("Dropoff: \(load.dropoffDate)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // DRIVERS & TRUCKS SECTION
            Section("Select Driver & Truck") {
                ForEach(drivers) { driver in
                    Button {
                        selectedDriver = driver
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(driver.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedDriver?.id == driver.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            Text("Vehicle: \(driver.vehicleUnit)")
                                .font(.subheadline).foregroundColor(.secondary)
                            Text("Score: \(driver.score) | Availability: \(driver.availability)")
                                .font(.caption).foregroundColor(.secondary)
                            Text("Inspection Score: \(driver.inspectionScore)")
                                .font(.caption).foregroundColor(.secondary)
                            Text("📞 \(driver.phone)  ✉️ \(driver.email)")
                                .font(.caption).foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // ASSIGN BUTTON
            Section {
                Button {
                    assignLoad()
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                        Text("Assign Load")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedLoad != nil && selectedDriver != nil ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(selectedLoad == nil || selectedDriver == nil)
            }
        }
        .navigationTitle("Assign Loads")
        .onAppear {
            fetchLoads()
            fetchDrivers()
        }
        .alert("Load Assigned!", isPresented: $showConfirmation) {
            Button("OK") {
                selectedLoad = nil
                selectedDriver = nil
            }
        } message: {
            if let load = selectedLoad, let driver = selectedDriver {
                Text("Load \(load.loadID) assigned to \(driver.name) — \(driver.vehicleUnit)")
            }
        }
    }

    func assignLoad() {
        guard let load = selectedLoad, let driver = selectedDriver else { return }

        Firestore.firestore().collection("loads").document(load.id).updateData([
            "assignedDriver": driver.name,
            "assignedVehicle": driver.vehicleUnit,
            "status": "Assigned"
        ]) { _ in
            showConfirmation = true
        }
    }

    func fetchLoads() {
        Firestore.firestore().collection("loads")
            .whereField("status", isEqualTo: "Unassigned")
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                loads = docs.map { doc in
                    let d = doc.data()
                    return LoadInfo(
                        id: doc.documentID,
                        loadID: d["loadID"] as? String ?? doc.documentID,
                        pickupLocation: d["pickupLocation"] as? String ?? "",
                        deliveryLocation: d["deliveryLocation"] as? String ?? "",
                        pickupDate: d["pickupDate"] as? String ?? "TBD",
                        dropoffDate: d["dropoffDate"] as? String ?? "TBD",
                        status: d["status"] as? String ?? "Unassigned"  // ✅ Pull value from Firestore
                    )
                }
            }
    }

    func fetchDrivers() {
        Firestore.firestore().collection("users")
            .whereField("role", isEqualTo: "Driver")
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                drivers = docs.map { doc in
                    let d = doc.data()
                    return DriverInfo(
                        id: doc.documentID,
                        name: d["name"] as? String ?? "",
                        vehicleUnit: d["vehicleUnit"] as? String ?? "Unassigned",
                        score: d["score"] as? String ?? "N/A",
                        availability: d["availability"] as? String ?? "Available",
                        inspectionScore: d["inspectionScore"] as? String ?? "N/A",
                        phone: d["phone"] as? String ?? "",
                        email: d["email"] as? String ?? ""
                    )
                }
            }
    }
}

// MARK: - Models
struct LoadInfo: Identifiable {
    let id: String
    var loadID: String
    var pickupLocation: String
    var deliveryLocation: String
    var pickupDate: String
    var dropoffDate: String
    var status: String  //
}

struct DriverInfo: Identifiable {
    let id: String
    var name: String
    var vehicleUnit: String
    var score: String
    var availability: String
    var inspectionScore: String
    var phone: String
    var email: String
}
