//
//  ClientInfo.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/4/26.
//


import SwiftUI
import FirebaseFirestore

struct ClientInfo: Identifiable {
    let id: String       // Client ID
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
                // BEFORE CLICK — just Client ID + company name
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
        // AFTER CLICK — full detail sheet
        .sheet(item: $selectedClient) { client in
            ClientDetailView(client: client)
        }
        .sheet(isPresented: $showAddClient) {
            AddClientView { newClient in clients.append(newClient) }
        }
    }

    func fetchClients() {
        Firestore.firestore().collection("clients").getDocuments { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
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

// MARK: - Client Detail (after click)
struct ClientDetailView: View {

    @Environment(\.dismiss) var dismiss
    let client: ClientInfo

    var body: some View {
        NavigationStack {
            List {
                Section("Client Info") {
                    DetailRow(label: "Client ID", value: client.id)
                    DetailRow(label: "Company Name", value: client.companyName)
                    DetailRow(label: "Broker Name", value: client.brokerName)
                }
                Section("Contact") {
                    DetailRow(label: "Phone", value: client.phone)
                    DetailRow(label: "Email", value: client.email)
                    DetailRow(label: "Address", value: client.address)
                }
                Section("Performance") {
                    DetailRow(label: "Score", value: client.score)
                }
            }
            .navigationTitle(client.companyName)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
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

    var onAdd: (ClientInfo) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Client Info") {
                    TextField("Company Name", text: $companyName)
                    TextField("Broker Name", text: $brokerName)
                }
                Section("Contact") {
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                    TextField("Email", text: $email).keyboardType(.emailAddress)
                    TextField("Address", text: $address)
                }
                Section("Performance") {
                    TextField("Score", text: $score)
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

    func saveClient() {
        let ref = Firestore.firestore().collection("clients").document()
        ref.setData([
            "companyName": companyName,
            "brokerName": brokerName,
            "phone": phone,
            "email": email,
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
        onAdd(newClient)
        dismiss()
    }
}
