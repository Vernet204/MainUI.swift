//
//  DispatcherLoadBoardView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/4/26.
//
import SwiftUI
import FirebaseFirestore

struct DispatcherLoadBoardView: View {

    @State private var loads: [LoadInfo] = []
    @State private var showCreateLoad = false
    @State private var selectedLoad: LoadInfo? = nil
    @State private var isLoading = true
    @State private var listener: ListenerRegistration? = nil

    var body: some View {
        List {
            if isLoading {
                ProgressView("Loading loads...")
            } else if loads.isEmpty {
                ContentUnavailableView(
                    "No Loads",
                    systemImage: "tray",
                    description: Text("Create a load to get started.")
                )
            } else {
                ForEach(loads) { load in
                    // ✅ Tap to edit
                    Button {
                        selectedLoad = load
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {

                            HStack {
                                Text("Load ID: \(load.loadID)")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(load.status)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(statusColor(load.status).opacity(0.15))
                                    .foregroundColor(statusColor(load.status))
                                    .clipShape(Capsule())

                                Image(systemName: "pencil.circle")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }

                            Divider()

                            Group {
                                Label(
                                    "Pickup: \(load.pickupLocation)",
                                    systemImage: "mappin.circle"
                                )
                                Label(
                                    "Date & Time: \(load.pickupDateTime.formatted(date: .abbreviated, time: .shortened))",
                                    systemImage: "clock"
                                )
                                Label(
                                    "Dropoff: \(load.deliveryLocation)",
                                    systemImage: "mappin.and.ellipse"
                                )
                                Label(
                                    "Date & Time: \(load.deliveryDateTime.formatted(date: .abbreviated, time: .shortened))",
                                    systemImage: "clock.fill"
                                )

                                if !load.commodity.isEmpty {
                                    Label(
                                        "Cargo: \(load.commodity)",
                                        systemImage: "shippingbox"
                                    )
                                }

                                if !load.rate.isEmpty {
                                    Label(
                                        "Rate: $\(load.rate)",
                                        systemImage: "dollarsign.circle"
                                    )
                                    .foregroundColor(.green)
                                }

                                // ✅ Show assigned driver if any
                                if !load.assignedDriver.isEmpty {
                                    Label(
                                        "Driver: \(load.assignedDriver)",
                                        systemImage: "person.fill"
                                    )
                                    .foregroundColor(.blue)
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .onDelete { indexSet in
                    let ids = indexSet.map { loads[$0].id }
                    loads.remove(atOffsets: indexSet)
                    ids.forEach { id in
                        Firestore.firestore()
                            .collection("loads")
                            .document(id)
                            .delete()
                    }
                }
            }
        }
        .navigationTitle("Load Board")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateLoad = true
                } label: {
                    Label("Add Load", systemImage: "plus")
                }
            }
        }
        .onAppear { startListening() }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
        .sheet(isPresented: $showCreateLoad) {
            CreateLoadView()
        }
        // ✅ Edit sheet
        .sheet(item: $selectedLoad) { load in
            EditLoadView(load: load) {
                // Listener will auto-update
            }
        }
    }

    // MARK: - Real-time Listener
    func startListening() {
        listener?.remove()

        listener = Firestore.firestore()
            .collection("loads")
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else { return }

                DispatchQueue.main.async {
                    loads = docs.compactMap { doc in
                        let d = doc.data()
                        let pickupDT = (d["pickupDateTime"] as? Timestamp)?.dateValue() ?? Date()
                        let deliveryDT = (d["deliveryDateTime"] as? Timestamp)?.dateValue() ?? Date()

                        return LoadInfo(
                            id: doc.documentID,
                            loadID: d["loadID"] as? String ?? doc.documentID,
                            pickupLocation: d["pickupLocation"] as? String ?? "",
                            deliveryLocation: d["deliveryLocation"] as? String ?? "",
                            pickupDateTime: pickupDT,
                            deliveryDateTime: deliveryDT,
                            status: d["status"] as? String ?? "Unassigned",
                            commodity: d["commodity"] as? String ?? "",
                            rate: d["rate"] as? String ?? "",
                            weight: d["weight"] as? String ?? "",
                            assignedDriver: d["assignedDriver"] as? String ?? ""
                        )
                    }
                    .sorted { $0.pickupDateTime < $1.pickupDateTime }
                    isLoading = false
                }
            }
    }

    func statusColor(_ status: String) -> Color {
        switch status {
        case "Unassigned": return .orange
        case "Assigned":   return .blue
        case "In Transit": return .purple
        case "Delivered":  return .green
        default:           return .gray
        }
    }
}

// MARK: - Edit Load View
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

    let statuses = ["Unassigned", "Assigned", "In Transit", "Delivered"]

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

                // ✅ Driver assignment
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

                    // ✅ Switch driver picker
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
            .navigationTitle("Edit Load")
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

        // ✅ Update status based on driver assignment
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
                "pickupLocation": pickupLocation,
                "deliveryLocation": deliveryLocation,
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
                    } else {
                        onSave()
                        dismiss()
                    }
                }
            }
    }
}
