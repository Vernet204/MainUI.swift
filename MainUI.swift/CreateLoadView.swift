//
//  CreateLoadView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/15/26.
//
import SwiftUI
import FirebaseFirestore

struct CreateLoadView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var loadID = ""
    @State private var pickup = ""
    @State private var delivery = ""
    @State private var weight = ""
    @State private var rate = ""
    @State private var pickupDateTime = Date()
    @State private var deliveryDateTime = Date().addingTimeInterval(3600 * 8)
    @State private var commodity = ""
    @State private var specialInstructions = ""
    @State private var errorMessage = ""
    @State private var isCreating = false
    // Add to state variables:
    @State private var clients: [ClientOption] = []
    @State private var selectedClient: ClientOption? = nil
    @State private var showAddClient = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // LOAD INFO
                    FormCard(title: "Load Info") {
                        VStack(spacing: 12) {
                            TextField("Load ID (Ex: LD-1003)", text: $loadID)
                                .textInputAutocapitalization(.characters)
                                .textFieldStyle(.roundedBorder)

                            TextField("Commodity / Cargo Type", text: $commodity)
                                .textFieldStyle(.roundedBorder)

                            TextField("Weight (lbs)", text: $weight)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)

                            TextField("Rate ($)", text: $rate)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    FormCard(title: "🏢 Client & Broker") {
                        VStack(spacing: 12) {
                            Picker("Select Client", selection: $selectedClient) {
                                Text("Select a client...").tag(Optional<ClientOption>(nil))
                                ForEach(clients) { client in
                                    Text("\(client.companyName) — \(client.brokerName)")
                                        .tag(Optional(client))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if let client = selectedClient {
                                HStack {
                                    Image(systemName: "building.2.fill")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(client.companyName)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Text("Broker: \(client.brokerName)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            // ✅ Add new client button
                            Button {
                                showAddClient = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Add New Client")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.green.opacity(0.12))
                                .foregroundColor(.green)
                                .cornerRadius(10)
                            }
                        }
                    }
                    // PICKUP
                    FormCard(title: "📍 Pickup") {
                        VStack(spacing: 12) {
                            TextField("Pickup Location", text: $pickup)
                                .textFieldStyle(.roundedBorder)

                            DatePicker(
                                "Pickup Date & Time",
                                selection: $pickupDateTime,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .onChange(of: pickupDateTime) { newValue in
                                if deliveryDateTime <= newValue {
                                    deliveryDateTime = newValue.addingTimeInterval(3600 * 4)
                                }
                            }
                        }
                    }

                    // DELIVERY
                    FormCard(title: "🏁 Delivery") {
                        VStack(spacing: 12) {
                            TextField("Delivery Location", text: $delivery)
                                .textFieldStyle(.roundedBorder)

                            DatePicker(
                                "Delivery Date & Time",
                                selection: $deliveryDateTime,
                                in: pickupDateTime...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                    }

                    // SPECIAL INSTRUCTIONS
                    FormCard(title: "📋 Special Instructions") {
                        TextField(
                            "Any special requirements...",
                            text: $specialInstructions,
                            axis: .vertical
                        )
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                    }

                    // ✅ Duration preview
                    if !pickup.isEmpty && !delivery.isEmpty {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.blue)
                            Text("Estimated duration: \(estimatedDuration)")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: createLoad) {
                        if isCreating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            HStack {
                                Image(systemName: "shippingbox.fill")
                                Text("Create Load")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                    }
                    .disabled(isCreating)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Create Load")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Close") { dismiss() }
                                    .disabled(isCreating)
                            }
                        }
                        .onAppear { fetchClients() }
                        .sheet(isPresented: $showAddClient, onDismiss: {
                // ✅ Refresh client list after adding
                fetchClients()
            }) {
                QuickAddClientView { newClient in
                    // ✅ Auto-select the newly added client
                    selectedClient = ClientOption(
                        id: newClient.id,
                        companyName: newClient.companyName,
                        brokerName: newClient.brokerName
                    )
                }
            }
        }
    }

    // MARK: - Estimated Duration
    var estimatedDuration: String {
        let diff = deliveryDateTime.timeIntervalSince(pickupDateTime)
        let hours = Int(diff / 3600)
        let minutes = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }

    
    func fetchClients() {
        Firestore.firestore()
            .collection("clients")
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    clients = docs.map { doc in
                        let d = doc.data()
                        return ClientOption(
                            id: doc.documentID,
                            companyName: d["companyName"] as? String ?? "",
                            brokerName: d["brokerName"] as? String ?? ""
                        )
                    }.filter { !$0.companyName.isEmpty }
                }
            }
    }
    
    // MARK: - Create Load
    func createLoad() {
        guard !pickup.isEmpty else { errorMessage = "Enter pickup location."; return }
        guard !delivery.isEmpty else { errorMessage = "Enter delivery location."; return }
        guard !rate.isEmpty else { errorMessage = "Enter rate."; return }
        guard deliveryDateTime > pickupDateTime else {
            errorMessage = "Delivery must be after pickup."
            return
        }

        let finalLoadID = loadID.isEmpty
            ? "LD-\(Int.random(in: 1000...9999))"
            : loadID.uppercased().trimmingCharacters(in: .whitespaces)

        isCreating = true
        errorMessage = ""

        Firestore.firestore()
            .collection("loads")
            .whereField("loadID", isEqualTo: finalLoadID)
            .getDocuments { snapshot, error in
                if let snapshot = snapshot, !snapshot.documents.isEmpty {
                    DispatchQueue.main.async {
                        errorMessage = "Load ID \(finalLoadID) already exists."
                        isCreating = false
                    }
                    return
                }

                Firestore.firestore().collection("loads").addDocument(data: [
                    "loadID": finalLoadID,
                    "pickupLocation": pickup.trimmingCharacters(in: .whitespaces),
                    "deliveryLocation": delivery.trimmingCharacters(in: .whitespaces),
                    "pickupDateTime": Timestamp(date: pickupDateTime),
                    "deliveryDateTime": Timestamp(date: deliveryDateTime),
                    "weight": weight,
                    "rate": rate,
                    "commodity": commodity,
                    "specialInstructions": specialInstructions,
                    "status": "Unassigned",
                    "assignedDriver": "",
                    "assignedDriverID": "",
                    "assignedVehicle": "",
                    // ✅ Client & Broker
                    "clientID": selectedClient?.id ?? "",
                    "clientName": selectedClient?.companyName ?? "",
                    "brokerName": selectedClient?.brokerName ?? "",
                    "createdAt": Timestamp()
                ]) { error in
                    DispatchQueue.main.async {
                        isCreating = false
                        if let error = error {
                            errorMessage = error.localizedDescription
                        } else {
                            dismiss()
                        }
                    }
                }
            }
    }
}

// MARK: - Form Card
struct FormCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
        .padding(.horizontal)
    }
    
}
// Add model at bottom of file:
struct ClientOption: Identifiable, Hashable {
    let id: String
    var companyName: String
    var brokerName: String
}

// MARK: - Quick Add Client View
struct QuickAddClientView: View {

    @Environment(\.dismiss) var dismiss
    var onAdd: (ClientOption) -> Void

    @State private var companyName = ""
    @State private var brokerName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var errorMessage = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Company Info") {
                    TextField("Company Name", text: $companyName)
                    TextField("Broker Name", text: $brokerName)
                }

                Section("Contact (Optional)") {
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
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
                        saveClient()
                    } label: {
                        if isSaving {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Client").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle("New Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    func saveClient() {
        guard !companyName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Company name is required."
            return
        }
        guard !brokerName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Broker name is required."
            return
        }

        isSaving = true
        errorMessage = ""

        // ✅ Duplicate check
        Firestore.firestore()
            .collection("clients")
            .whereField("companyName", isEqualTo: companyName)
            .getDocuments { snapshot, _ in
                if let count = snapshot?.documents.count, count > 0 {
                    DispatchQueue.main.async {
                        errorMessage = "A client named '\(companyName)' already exists."
                        isSaving = false
                    }
                    return
                }

                // ✅ Save to Firestore
                var ref: DocumentReference?
                ref = Firestore.firestore()
                    .collection("clients")
                    .addDocument(data: [
                        "companyName": companyName.trimmingCharacters(in: .whitespaces),
                        "brokerName": brokerName.trimmingCharacters(in: .whitespaces),
                        "phone": phone,
                        "email": email,
                        "createdAt": Timestamp()
                    ]) { error in
                        DispatchQueue.main.async {
                            isSaving = false
                            if let error = error {
                                errorMessage = error.localizedDescription
                            } else if let id = ref?.documentID {
                                // ✅ Pass new client back to CreateLoadView
                                onAdd(ClientOption(
                                    id: id,
                                    companyName: companyName,
                                    brokerName: brokerName
                                ))
                                dismiss()
                            }
                        }
                    }
            }
    }
}

#Preview {
    CreateLoadView()
}
