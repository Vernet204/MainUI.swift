//
//  ClientInfo.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/4/26.
//
import SwiftUI
import FirebaseFirestore

struct ClienteleView: View {

    @State private var clients: [ClientSummary] = []
    @State private var isLoading = true
    @State private var showAddClient = false
    @State private var selectedClient: ClientSummary? = nil
    @State private var listener: ListenerRegistration? = nil

    var totalRevenue: Double {
        clients.reduce(0) { $0 + $1.totalRevenue }
    }

    var body: some View {
        NavigationStack {
            List {

                // MARK: - Summary Stats
                Section {
                    HStack(spacing: 0) {
                        ClientStatPill(
                            value: "\(clients.count)",
                            label: "Total Clients",
                            color: .blue
                        )
                        Divider().frame(height: 30)
                        ClientStatPill(
                            value: "$\(Int(totalRevenue))",
                            label: "Total Revenue",
                            color: .green
                        )
                        Divider().frame(height: 30)
                        ClientStatPill(
                            value: "\(clients.reduce(0) { $0 + $1.totalLoads })",
                            label: "Total Loads",
                            color: .purple
                        )
                    }
                }

                // MARK: - Client List
                Section("Clients") {
                    if isLoading {
                        ProgressView("Loading clients...")
                    } else if clients.isEmpty {
                        ContentUnavailableView(
                            "No Clients",
                            systemImage: "building.2",
                            description: Text("Add a client to get started.")
                        )
                    } else {
                        ForEach(clients.sorted { $0.totalRevenue > $1.totalRevenue }) { client in
                            Button {
                                selectedClient = client
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {

                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(client.companyName)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            Text("Broker: \(client.brokerName)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }

                                    Divider()

                                    HStack(spacing: 16) {
                                        Label(
                                            "\(client.totalLoads) loads",
                                            systemImage: "shippingbox.fill"
                                        )
                                        .font(.caption)
                                        .foregroundColor(.blue)

                                        Label(
                                            "$\(Int(client.totalRevenue))",
                                            systemImage: "dollarsign.circle.fill"
                                        )
                                        .font(.caption)
                                        .foregroundColor(.green)

                                        if let last = client.lastLoadDate {
                                            Label(
                                                last.formatted(date: .abbreviated, time: .omitted),
                                                systemImage: "clock"
                                            )
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
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
            .onDisappear {
                listener?.remove()
                listener = nil
            }
            .sheet(isPresented: $showAddClient) {
                AddClientView()
            }
            .sheet(item: $selectedClient) { client in
                ClientDetailView(client: client)
            }
        }
    }

    // MARK: - Fetch Clients + Load Stats
    func fetchClients() {
        isLoading = true

        Firestore.firestore()
            .collection("clients")
            .getDocuments { snapshot, _ in
                guard let clientDocs = snapshot?.documents else {
                    DispatchQueue.main.async { isLoading = false }
                    return
                }

                let group = DispatchGroup()
                var summaries: [ClientSummary] = []

                for doc in clientDocs {
                    let d = doc.data()
                    let companyName = d["companyName"] as? String ?? ""
                    let brokerName = d["brokerName"] as? String ?? ""
                    let phone = d["phone"] as? String ?? ""
                    let email = d["email"] as? String ?? ""

                    group.enter()

                    // ✅ Fetch delivered loads for this client
                    Firestore.firestore()
                        .collection("loads")
                        .whereField("clientID", isEqualTo: doc.documentID)
                        .getDocuments { loadSnap, _ in
                            let loadDocs = loadSnap?.documents ?? []

                            let totalLoads = loadDocs.count
                            var totalRevenue: Double = 0
                            var lastLoadDate: Date? = nil

                            for loadDoc in loadDocs {
                                let ld = loadDoc.data()
                                let rate = Double(ld["rate"] as? String ?? "0") ?? 0
                                let status = ld["status"] as? String ?? ""
                                let deliveredAt = (ld["deliveredAt"] as? Timestamp)?.dateValue()

                                if status.lowercased() == "delivered" {
                                    totalRevenue += rate
                                    if let da = deliveredAt {
                                        if lastLoadDate == nil || da > lastLoadDate! {
                                            lastLoadDate = da
                                        }
                                    }
                                }
                            }

                            summaries.append(ClientSummary(
                                id: doc.documentID,
                                companyName: companyName,
                                brokerName: brokerName,
                                phone: phone,
                                email: email,
                                totalLoads: totalLoads,
                                totalRevenue: totalRevenue,
                                lastLoadDate: lastLoadDate
                            ))

                            group.leave()
                        }
                }

                group.notify(queue: .main) {
                    clients = summaries
                    isLoading = false
                }
            }
    }
}

// MARK: - Client Detail View
struct ClientDetailView: View {

    @Environment(\.dismiss) var dismiss
    let client: ClientSummary

    var body: some View {
        NavigationStack {
            List {

                Section("Company Info") {
                    DetailRow(label: "Company", value: client.companyName)
                    DetailRow(label: "Broker", value: client.brokerName)
                    if !client.phone.isEmpty {
                        DetailRow(label: "Phone", value: client.phone)
                    }
                    if !client.email.isEmpty {
                        DetailRow(label: "Email", value: client.email)
                    }
                }

                Section("Load History") {
                    DetailRow(label: "Total Loads", value: "\(client.totalLoads)")
                    DetailRow(
                        label: "Total Revenue",
                        value: "$\(String(format: "%.2f", client.totalRevenue))"
                    )
                    if let last = client.lastLoadDate {
                        DetailRow(
                            label: "Last Load",
                            value: last.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                }
            }
            .navigationTitle(client.companyName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Add Client View
struct AddClientView: View {

    @Environment(\.dismiss) var dismiss
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
                Section("Contact") {
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
            .navigationTitle("Add Client")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    func saveClient() {
        guard !companyName.isEmpty else {
            errorMessage = "Company name is required."
            return
        }
        guard !brokerName.isEmpty else {
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
                        errorMessage = "A client with this company name already exists."
                        isSaving = false
                    }
                    return
                }

                Firestore.firestore().collection("clients").addDocument(data: [
                    "companyName": companyName,
                    "brokerName": brokerName,
                    "phone": phone,
                    "email": email,
                    "createdAt": Timestamp()
                ]) { _ in
                    DispatchQueue.main.async {
                        isSaving = false
                        dismiss()
                    }
                }
            }
    }
}

// MARK: - Stat Pill
struct ClientStatPill: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}

// MARK: - Models
struct ClientSummary: Identifiable {
    let id: String
    var companyName: String
    var brokerName: String
    var phone: String
    var email: String
    var totalLoads: Int
    var totalRevenue: Double
    var lastLoadDate: Date?
}
