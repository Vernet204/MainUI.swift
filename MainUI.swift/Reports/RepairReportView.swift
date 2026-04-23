//
//  RepairReportView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/16/26.
//
import SwiftUI
import FirebaseFirestore

struct RepairReportView: View {

    // ✅ Pre-fill support — passed when navigating from Could Not Deliver / Vehicle Breakdown
    var prefilledDriverName: String = ""
    var prefilledVehicleUnit: String = ""

    @State private var selectedDriver: ReportDriver? = nil
    @State private var selectedVehicle: ReportVehicle? = nil
    @State private var trailerID = ""
    @State private var drivers: [ReportDriver] = []
    @State private var vehicles: [ReportVehicle] = []
    @State private var issueType = "Mechanical"
    @State private var severity = "Medium"
    @State private var issueDescription = ""
    @State private var location = ""
    @State private var reportSubmitted = false
    @State private var errorMessage = ""

    let issueTypes = [
        "Mechanical", "Tire Issue", "Engine Problem",
        "Trailer Damage", "Electrical", "Other"
    ]
    let severityLevels = ["Low", "Medium", "High", "Critical"]

    var body: some View {
        Form {

            Section("Driver Information") {
                Picker("Select Driver", selection: $selectedDriver) {
                    Text("Select a driver...").tag(Optional<ReportDriver>(nil))
                    ForEach(drivers) { driver in
                        Text(driver.name).tag(Optional(driver))
                    }
                }
                .pickerStyle(.menu)
            }

            Section("Vehicle Information") {
                Picker("Select Truck", selection: $selectedVehicle) {
                    Text("Select a vehicle...").tag(Optional<ReportVehicle>(nil))
                    ForEach(vehicles) { vehicle in
                        Text("\(vehicle.unitNumber) — \(vehicle.plate)").tag(Optional(vehicle))
                    }
                }
                .pickerStyle(.menu)

                TextField("Trailer ID (optional)", text: $trailerID)
            }

            Section("Repair Issue Details") {
                Picker("Issue Type", selection: $issueType) {
                    ForEach(issueTypes, id: \.self) { Text($0) }
                }

                Picker("Severity Level", selection: $severity) {
                    ForEach(severityLevels, id: \.self) { Text($0) }
                }

                TextField("Current Location", text: $location)

                TextField("Describe the Issue...", text: $issueDescription, axis: .vertical)
                    .lineLimit(3...6)
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage).foregroundColor(.red).font(.caption)
                }
            }

            Section {
                Button {
                    submitRepairReport()
                } label: {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                        Text("Submit Repair Report")
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(Color.orange).foregroundColor(.white).cornerRadius(12)
                }
            }
        }
        .navigationTitle("Repair Report")
        .onAppear {
            fetchDrivers()
            fetchVehicles()
        }
        .alert("Repair Report Submitted", isPresented: $reportSubmitted) {
            Button("OK", role: .cancel) {}
        }
    }

    func fetchDrivers() {
        Firestore.firestore()
            .collection("users")
            .whereField("role", isEqualTo: "Driver")
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    drivers = docs.map {
                        ReportDriver(id: $0.documentID, name: $0.data()["name"] as? String ?? "")
                    }.filter { !$0.name.isEmpty }

                    // ✅ Pre-select driver if name was passed in
                    if !prefilledDriverName.isEmpty {
                        selectedDriver = drivers.first { $0.name == prefilledDriverName }
                    }
                }
            }
    }

    func fetchVehicles() {
        Firestore.firestore()
            .collection("vehicles")
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    vehicles = docs.map { doc in
                        let d = doc.data()
                        return ReportVehicle(
                            id: doc.documentID,
                            unitNumber: d["unitNumber"] as? String ?? "",
                            plate: d["plate"] as? String ?? ""
                        )
                    }.filter { !$0.unitNumber.isEmpty }

                    // ✅ Pre-select vehicle if unit number was passed in
                    if !prefilledVehicleUnit.isEmpty {
                        selectedVehicle = vehicles.first { $0.unitNumber == prefilledVehicleUnit }
                    }
                }
            }
    }

    func submitRepairReport() {
        guard let driver = selectedDriver else {
            errorMessage = "Please select a driver."
            return
        }
        guard let vehicle = selectedVehicle else {
            errorMessage = "Please select a vehicle."
            return
        }
        errorMessage = ""

        let reportNumber = "REP-\(Int.random(in: 1000...9999))"

        Firestore.firestore()
            .collection("reports")
            .addDocument(data: [
                "reportNumber": reportNumber,
                "type": "repair",
                "driverName": driver.name,
                "truckID": vehicle.unitNumber,
                "vehicleNumber": vehicle.unitNumber,
                "trailerID": trailerID,
                "issueType": issueType,
                "severity": severity,
                "issueDescription": issueDescription,
                "location": location,
                "dateReported": Timestamp(),
                "status": "Open"
            ]) { error in
                if let error = error {
                    print("Error saving repair report:", error.localizedDescription)
                    return
                }
                if self.severity == "High" || self.severity == "Critical" {
                    Firestore.firestore()
                        .collection("vehicles")
                        .document(vehicle.id)
                        .updateData([
                            "status": "In Maintenance",
                            "inspectionStatus": "Needs Repair"
                        ])
                }
                self.reportSubmitted = true
            }
    }
}

#Preview {
    NavigationStack {
        RepairReportView()
    }
    .environmentObject(AppState())
}
