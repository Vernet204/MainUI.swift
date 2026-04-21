import SwiftUI
import FirebaseFirestore

struct DVIRInspectionView: View {

    @State private var selectedDriver: ReportDriver? = nil
    @State private var selectedVehicle: ReportVehicle? = nil
    @State private var trailerID = ""

    @State private var drivers: [ReportDriver] = []
    @State private var vehicles: [ReportVehicle] = []

    @State private var odometer = ""
    @State private var inspectionDate = Date()

    @State private var brakesOK = false
    @State private var tiresOK = false
    @State private var lightsOK = false
    @State private var mirrorsOK = false
    @State private var hornOK = false
    @State private var engineOK = false

    @State private var defectsFound = false
    @State private var defectDescription = ""
    @State private var showConfirmation = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {

                // MARK: - Driver & Vehicle Pickers
                Section("Driver Information") {
                    Picker("Select Driver", selection: $selectedDriver) {
                        Text("Select a driver...").tag(Optional<ReportDriver>(nil))
                        ForEach(drivers) { driver in
                            Text(driver.name).tag(Optional(driver))
                        }
                    }
                    .pickerStyle(.menu)

                    DatePicker(
                        "Inspection Date",
                        selection: $inspectionDate,
                        displayedComponents: .date
                    )
                }

                Section("Vehicle Details") {
                    Picker("Select Truck", selection: $selectedVehicle) {
                        Text("Select a vehicle...").tag(Optional<ReportVehicle>(nil))
                        ForEach(vehicles) { vehicle in
                            Text("\(vehicle.unitNumber) — \(vehicle.plate)").tag(Optional(vehicle))
                        }
                    }
                    .pickerStyle(.menu)

                    TextField("Trailer ID (optional)", text: $trailerID)

                    TextField("Odometer Reading", text: $odometer)
                        .keyboardType(.numberPad)
                }

                // MARK: - Safety Checklist
                Section("Safety Inspection Checklist") {
                    Toggle("Brakes Operational", isOn: $brakesOK)
                    Toggle("Tires in Good Condition", isOn: $tiresOK)
                    Toggle("Lights & Signals Working", isOn: $lightsOK)
                    Toggle("Mirrors Secure & Functional", isOn: $mirrorsOK)
                    Toggle("Horn Working", isOn: $hornOK)
                    Toggle("Engine & Fluids OK", isOn: $engineOK)
                }

                // MARK: - Defects
                Section("Defects & Issues") {
                    Toggle("Defects Found?", isOn: $defectsFound)
                    if defectsFound {
                        TextField(
                            "Describe Defects...",
                            text: $defectDescription,
                            axis: .vertical
                        )
                        .lineLimit(3...6)
                    }
                }

                // MARK: - Error
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                // MARK: - Submit
                Section {
                    Button {
                        submitDVIR()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            Text("Submit DVIR Report")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .navigationTitle("DVIR Inspection")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                fetchDrivers()
                fetchVehicles()
            }
            .alert("DVIR Submitted Successfully", isPresented: $showConfirmation) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    // MARK: - Fetch Drivers
    func fetchDrivers() {
        Firestore.firestore()
            .collection("users")
            .whereField("role", isEqualTo: "Driver")
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    drivers = docs.map { doc in
                        ReportDriver(
                            id: doc.documentID,
                            name: doc.data()["name"] as? String ?? ""
                        )
                    }.filter { !$0.name.isEmpty }
                }
            }
    }

    // MARK: - Fetch Vehicles
    func fetchVehicles() {
        Firestore.firestore()
            .collection("vehicles")
            .whereField("status", isEqualTo: "Active")
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
                }
            }
    }

    // MARK: - Submit DVIR
    func submitDVIR() {
        guard let driver = selectedDriver else {
            errorMessage = "Please select a driver."
            return
        }
        guard let vehicle = selectedVehicle else {
            errorMessage = "Please select a vehicle."
            return
        }
        errorMessage = ""

        let reportNumber = "DVIR-\(Int.random(in: 1000...9999))"

        Firestore.firestore()
            .collection("reports")
            .addDocument(data: [
                "reportNumber": reportNumber,
                "type": "inspection",
                "driver": driver.name,
                "driverName": driver.name,
                "truckID": vehicle.unitNumber,
                "vehicleNumber": vehicle.unitNumber,
                "trailerID": trailerID,
                "odometer": odometer,
                "inspectionDate": Timestamp(date: inspectionDate),
                "brakesOK": brakesOK,
                "tiresOK": tiresOK,
                "lightsOK": lightsOK,
                "mirrorsOK": mirrorsOK,
                "hornOK": hornOK,
                "engineOK": engineOK,
                "defectsFound": defectsFound,
                "defectDescription": defectDescription,
                "status": defectsFound ? "Open" : "Resolved"
            ]) { error in
                if let error = error {
                    print("❌ Error submitting DVIR:", error.localizedDescription)
                    return
                }
                self.updateVehicleStatus(vehicle: vehicle, driver: driver)
                showConfirmation = true
            }
    }

    // MARK: - Update Vehicle Status
    func updateVehicleStatus(vehicle: ReportVehicle, driver: ReportDriver) {
        let ref = Firestore.firestore()
            .collection("vehicles")
            .document(vehicle.id)

        if defectsFound {
            ref.updateData([
                "status": "In Maintenance",
                "inspectionStatus": "Failed",
                "lastInspectionDate": Timestamp(date: inspectionDate),
                "lastInspectedBy": driver.name
            ])
        } else {
            ref.updateData([
                "inspectionStatus": "Passed",
                "lastInspectionDate": Timestamp(date: inspectionDate),
                "lastInspectedBy": driver.name
            ])
        }
    }
}

#Preview {
    DVIRInspectionView()
}
