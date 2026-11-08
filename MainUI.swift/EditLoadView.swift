//
//  EditLoadView.swift
//  MainUI.swift
//
//  Multi-stop load editor.
//


import SwiftUI
import FirebaseFirestore

struct EditLoadView: View {

    @Environment(\.dismiss) var dismiss
    let load: LoadInfo
    var onSave: () -> Void

    @State private var stops: [Stop] = []
    @State private var weight = ""
    @State private var rate = ""
    @State private var commodity = ""
    @State private var specialInstructions = ""
    @State private var assignedDriver = ""
    @State private var status = "Unassigned"
    @State private var availableDrivers: [DriverOption] = []
    @State private var isSaving = false
    @State private var errorMessage = ""
    @State private var showUnassignConfirm = false

    //  Full status list for dispatcher editing
    let statuses = ["Unassigned", "Assigned", "Accepted", "Declined", "In Transit", "Delivered"]

    var body: some View {
        NavigationStack {
            Form {

                Section("Load Info") {
                    DetailRow(label: "Load ID", value: load.loadID)
                    TextField("Commodity", text: $commodity)
                    TextField("Weight (lbs)", text: $weight)
                        .keyboardType(.numberPad)
                    TextField("Rate ($)", text: $rate)
                        .keyboardType(.decimalPad)
                }

                Section("Stops") {
                    StopsEditor(stops: $stops)
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(statuses, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                }

                //  Driver Assignment
                Section("Driver Assignment") {
                    if assignedDriver.isEmpty {
                        Text("No driver assigned")
                            .foregroundColor(.secondary)
                    } else {
                        HStack {
                            Label(assignedDriver, systemImage: "person.fill")
                                .foregroundColor(.blue)
                            Spacer()
                            Button("Unassign") {
                                showUnassignConfirm = true
                            }
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                    }

                    //  Switch driver
                    Picker("Switch Driver", selection: $assignedDriver) {
                        Text("Unassigned").tag("")
                        ForEach(availableDrivers) { driver in
                            Text(driver.name).tag(driver.name)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Special Instructions") {
                    TextField(
                        "Special requirements...",
                        text: $specialInstructions,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button {
                        saveChanges()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Changes")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle("Edit Load \(load.loadID)")
            .onAppear {
                loadFields()
                fetchDrivers()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                "Unassign Driver?",
                isPresented: $showUnassignConfirm,
                titleVisibility: .visible
            ) {
                Button("Yes, Unassign", role: .destructive) {
                    assignedDriver = ""
                    status = "Unassigned"
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove \(assignedDriver) from this load and set it back to Unassigned.")
            }
        }
    }

    // MARK: - Load Fields
    func loadFields() {
        //  Prefer the live stops array from LoadInfo; if the load predates the redesign
        //  and only has flat fields, LoadInfo.decodeStops already synthesized a 2-stop pair.
        stops = load.stops.isEmpty
            ? [Stop(type: .pickup,   address: "", datetime: Date()),
               Stop(type: .delivery, address: "", datetime: Date().addingTimeInterval(3600 * 8))]
            : load.stops
        weight = load.weight
        rate = load.rate
        commodity = load.commodity
        status = load.status
        assignedDriver = load.assignedDriver
    }

    // MARK: - Fetch Drivers
    func fetchDrivers() {
        Firestore.firestore()
            .collection("users")
            .whereField("role", isEqualTo: "Driver")
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    availableDrivers = docs.map { doc in
                        DriverOption(
                            id: doc.documentID,
                            name: doc.data()["name"] as? String ?? ""
                        )
                    }
                }
            }
    }

    // MARK: - Save Changes
    func saveChanges() {
        let trimmedStops = stops.map {
            var s = $0
            s.address = s.address.trimmingCharacters(in: .whitespaces)
            s.reference = s.reference.trimmingCharacters(in: .whitespaces)
            return s
        }.filter { !$0.address.isEmpty }

        guard trimmedStops.firstPickup != nil else {
            errorMessage = "Add at least one pickup stop."
            return
        }
        guard trimmedStops.lastDelivery != nil else {
            errorMessage = "Add at least one delivery stop."
            return
        }

        isSaving = true
        errorMessage = ""

        //  Auto-correct status based on driver assignment
        let finalStatus: String
        if assignedDriver.isEmpty {
            finalStatus = "Unassigned"
        } else if status == "Unassigned" {
            finalStatus = "Assigned"
        } else {
            finalStatus = status
        }

        var updates: [String: Any] = [
            "weight": weight,
            "rate": rate,
            "commodity": commodity,
            "specialInstructions": specialInstructions,
            "assignedDriver": assignedDriver,
            "status": finalStatus
        ]
        //  stops array + mirrored top-level fields
        updates.merge(LoadWrite.stopFields(trimmedStops)) { _, new in new }

        Firestore.firestore()
            .collection("loads")
            .document(load.id)
            .updateData(updates) { error in
                DispatchQueue.main.async {
                    isSaving = false
                    if let error = error {
                        errorMessage = error.localizedDescription
                        print("❌ Error saving load: \(error.localizedDescription)")
                    } else {
                        print("✅ Load \(load.loadID) updated successfully")
                        onSave()
                        dismiss()
                    }
                }
            }
    }
}
