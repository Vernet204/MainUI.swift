//
//  EditLoadView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/19/26.
//


import SwiftUI
import FirebaseFirestore

struct EditLoadView: View {

    @Environment(\.dismiss) var dismiss
    let load: LoadInfo
    var onSave: () -> Void

    @State private var pickupLocation = ""
    @State private var deliveryLocation = ""
    @State private var pickupDateTime = Date()
    @State private var deliveryDateTime = Date()
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

    // ✅ Full status list for dispatcher editing
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

                Section("Pickup") {
                    TextField("Pickup Location", text: $pickupLocation)
                    DatePicker(
                        "Date & Time",
                        selection: $pickupDateTime,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .onChange(of: pickupDateTime) { newValue in
                        if deliveryDateTime <= newValue {
                            deliveryDateTime = newValue.addingTimeInterval(3600 * 4)
                        }
                    }
                }

                Section("Delivery") {
                    TextField("Delivery Location", text: $deliveryLocation)
                    DatePicker(
                        "Date & Time",
                        selection: $deliveryDateTime,
                        in: pickupDateTime...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(statuses, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.menu)
                }

                // ✅ Driver Assignment
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

                    // ✅ Switch driver
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
        pickupLocation = load.pickupLocation
        deliveryLocation = load.deliveryLocation
        pickupDateTime = load.pickupDateTime
        deliveryDateTime = load.deliveryDateTime
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
        guard !pickupLocation.isEmpty else {
            errorMessage = "Enter pickup location."
            return
        }
        guard !deliveryLocation.isEmpty else {
            errorMessage = "Enter delivery location."
            return
        }

        isSaving = true
        errorMessage = ""

        // ✅ Auto-correct status based on driver assignment
        let finalStatus: String
        if assignedDriver.isEmpty {
            finalStatus = "Unassigned"
        } else if status == "Unassigned" {
            finalStatus = "Assigned"
        } else {
            finalStatus = status
        }

        Firestore.firestore()
            .collection("loads")
            .document(load.id)
            .updateData([
                "pickupLocation": pickupLocation.trimmingCharacters(in: .whitespaces),
                "deliveryLocation": deliveryLocation.trimmingCharacters(in: .whitespaces),
                "pickupDateTime": Timestamp(date: pickupDateTime),
                "deliveryDateTime": Timestamp(date: deliveryDateTime),
                "weight": weight,
                "rate": rate,
                "commodity": commodity,
                "specialInstructions": specialInstructions,
                "assignedDriver": assignedDriver,
                "status": finalStatus
            ]) { error in
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
