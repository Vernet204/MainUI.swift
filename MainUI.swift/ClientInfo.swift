//
//  ClientInfo.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/4/26.
//
import SwiftUI
import FirebaseFirestore

struct ClientInfo: Identifiable {
    let id: String
    var companyName: String
    var brokerName: String
    var phone: String
    var email: String
    var address: String
    var score: String
}

struct ClienteleView: View {

    @State private var clients: [ClientInfo] = []
    @State private var selectedClient: ClientInfo? = nil
    @State private var showAddClient = false

    var body: some View {
        List {
            ForEach(clients) { client in
                Button {
                    selectedClient = client
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(client.companyName)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("Client ID: \(client.id)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete { clients.remove(atOffsets: $0) }
        }
        .navigationTitle("Clientele")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddClient = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .onAppear { fetchClients() }
        .sheet(item: $selectedClient) { client in
            ClientDetailView(client: client) { updatedClient in
                if let index = clients.firstIndex(where: { $0.id == updatedClient.id }) {
                    clients[index] = updatedClient
                }
            }
        }
        .sheet(isPresented: $showAddClient) {
            AddClientView { newClient in clients.append(newClient) }
        }
    }

    func fetchClients() {
        Firestore.firestore().collection("clients").getDocuments { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            DispatchQueue.main.async {
                clients = docs.map { doc in
                    let d = doc.data()
                    return ClientInfo(
                        id: doc.documentID,
                        companyName: d["companyName"] as? String ?? "",
                        brokerName: d["brokerName"] as? String ?? "",
                        phone: d["phone"] as? String ?? "",
                        email: d["email"] as? String ?? "",
                        address: d["address"] as? String ?? "",
                        score: d["score"] as? String ?? ""
                    )
                }
            }
        }
    }
}

// MARK: - Client Detail View
struct ClientDetailView: View {

    @Environment(\.dismiss) var dismiss
    let client: ClientInfo
    var onUpdate: (ClientInfo) -> Void

    @State private var isEditing = false
    @State private var companyName = ""
    @State private var brokerName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var score = ""
    @State private var isSaving = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            List {
                if isEditing {

                    Section("Client Info") {
                        TextField("Company Name", text: $companyName)
                        TextField("Broker Name", text: $brokerName)
                    }

                    Section("Contact") {
                        TextField("Phone", text: $phone)
                            .keyboardType(.phonePad)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        TextField("Address", text: $address)
                    }

                    Section("Performance") {
                        TextField("Score", text: $score)
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

                } else {

                    Section("Client Info") {
                        DetailRow(label: "Client ID", value: client.id)
                        DetailRow(label: "Company Name", value: companyName)
                        DetailRow(label: "Broker Name", value: brokerName)
                    }

                    Section("Contact") {
                        DetailRow(label: "Phone", value: phone.isEmpty ? "—" : phone)
                        DetailRow(label: "Email", value: email.isEmpty ? "—" : email)
                        DetailRow(label: "Address", value: address.isEmpty ? "—" : address)
                    }

                    Section("Performance") {
                        DetailRow(label: "Score", value: score.isEmpty ? "—" : score)
                    }
                }
            }
            .navigationTitle(companyName.isEmpty ? "Client" : companyName)
            .onAppear { loadFields() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(isEditing ? "Cancel" : "Close") {
                        if isEditing {
                            isEditing = false
                            loadFields()
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            saveChanges()
                        } else {
                            isEditing = true
                        }
                    }
                    .fontWeight(isEditing ? .bold : .regular)
                }
            }
        }
    }

    func loadFields() {
        companyName = client.companyName
        brokerName = client.brokerName
        phone = client.phone
        email = client.email
        address = client.address
        score = client.score
    }

    func saveChanges() {
        guard !companyName.isEmpty else {
            errorMessage = "Company name cannot be empty."
            return
        }

        isSaving = true
        errorMessage = ""

        Firestore.firestore()
            .collection("clients")
            .document(client.id)
            .updateData([
                "companyName": companyName,
                "brokerName": brokerName,
                "phone": phone,
                "email": email,
                "address": address,
                "score": score
            ]) { error in
                DispatchQueue.main.async {
                    isSaving = false
                    if let error = error {
                        errorMessage = error.localizedDescription
                    } else {
                        let updated = ClientInfo(
                            id: client.id,
                            companyName: companyName,
                            brokerName: brokerName,
                            phone: phone,
                            email: email,
                            address: address,
                            score: score
                        )
                        onUpdate(updated)
                        isEditing = false
                    }
                }
            }
    }
}

// MARK: - Add Client
struct AddClientView: View {

    @Environment(\.dismiss) var dismiss
    @State private var companyName = ""
    @State private var brokerName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var address = ""
    @State private var score = ""
    @State private var errorMessage = ""

    var onAdd: (ClientInfo) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Client Info") {
                    TextField("Company Name", text: $companyName)
                    TextField("Broker Name", text: $brokerName)
                }
                Section("Contact") {
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Address", text: $address)
                }
                Section("Performance") {
                    TextField("Score", text: $score)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Client")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveClient() }
                }
            }
        }
    }

    // ✅ Single saveClient function with duplicate check
    func saveClient() {
        guard !companyName.isEmpty else {
            errorMessage = "Company name cannot be empty."
            return
        }

        Firestore.firestore()
            .collection("clients")
            .whereField(
                "companyName",
                isEqualTo: companyName.trimmingCharacters(in: .whitespaces)
            )
            .getDocuments { snapshot, error in
                if let snapshot = snapshot, !snapshot.documents.isEmpty {
                    DispatchQueue.main.async {
                        errorMessage = "A client with this company name already exists."
                    }
                    return
                }

                let ref = Firestore.firestore().collection("clients").document()
                ref.setData([
                    "companyName": companyName.trimmingCharacters(in: .whitespaces),
                    "brokerName": brokerName.trimmingCharacters(in: .whitespaces),
                    "phone": phone,
                    "email": email.lowercased().trimmingCharacters(in: .whitespaces),
                    "address": address,
                    "score": score
                ])

                let newClient = ClientInfo(
                    id: ref.documentID,
                    companyName: companyName,
                    brokerName: brokerName,
                    phone: phone,
                    email: email,
                    address: address,
                    score: score
                )

                DispatchQueue.main.async {
                    onAdd(newClient)
                    dismiss()
                }
            }
    }
}
