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
    var companyName:     String
    var brokerName:      String
    var contactName:     String = ""
    var phone:           String
    var email:           String
    var accountingEmail: String = ""
    var address:         String
    var mc:              String = ""
    var dot:             String = ""
    var score:           String
    var notes:           String = ""
}

struct ClientLoadStats {
    var count: Int = 0
    var revenue: Double = 0
}

struct ClienteleView: View {

    @State private var clients: [ClientInfo] = []
    @State private var selectedClient: ClientInfo? = nil
    @State private var showAddClient = false
    @State private var loadStats: [String: ClientLoadStats] = [:]

    var totalRevenue: Double { loadStats.values.reduce(0) { $0 + $1.revenue } }
    var totalLoads: Int { loadStats.values.reduce(0) { $0 + $1.count } }

    var sortedClients: [ClientInfo] {
        clients.sorted { (loadStats[$0.id]?.revenue ?? 0) > (loadStats[$1.id]?.revenue ?? 0) }
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 8) {
                    ClientStatPill(title: "Clients", value: "\(clients.count)", color: .blue)
                    ClientStatPill(title: "Revenue", value: "$\(Int(totalRevenue))", color: .green)
                    ClientStatPill(title: "Loads", value: "\(totalLoads)", color: .orange)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
            }

            ForEach(sortedClients) { client in
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
                        HStack(spacing: 6) {
                            Text("\(loadStats[client.id]?.count ?? 0) loads")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("•").font(.caption2).foregroundColor(.secondary)
                            Text("$\(Int(loadStats[client.id]?.revenue ?? 0))")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.vertical, 4)
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
        .onAppear {
            // Clients first so name-based fallback matching has the lookup table
            fetchClients { fetchLoadStats() }
        }
        // ✅ Pass onUpdate callback to handle local state update
        .sheet(item: $selectedClient) { client in
            ClientDetailView(
                client: client,
                stats: loadStats[client.id] ?? ClientLoadStats()
            ) { updatedClient in
                if let index = clients.firstIndex(where: { $0.id == updatedClient.id }) {
                    clients[index] = updatedClient
                }
            }
        }
        .sheet(isPresented: $showAddClient) {
            AddClientView { newClient in clients.append(newClient) }
        }
    }

    func fetchClients(completion: (() -> Void)? = nil) {
        Firestore.firestore().collection("clients").getDocuments { snapshot, _ in
            guard let docs = snapshot?.documents else { completion?(); return }
            DispatchQueue.main.async {
                clients = docs.map { doc in
                    let d = doc.data()
                    return ClientInfo(
                        id:              doc.documentID,
                        companyName:     d["companyName"]     as? String ?? "",
                        brokerName:      d["brokerName"]      as? String ?? "",
                        contactName:     d["contactName"]     as? String ?? "",
                        phone:           d["phone"]           as? String ?? "",
                        email:           d["email"]           as? String ?? "",
                        accountingEmail: d["accountingEmail"] as? String ?? "",
                        address:         d["address"]         as? String ?? "",
                        mc:              d["mc"]              as? String ?? "",
                        dot:             d["dot"]             as? String ?? "",
                        score:           d["score"]           as? String ?? "",
                        notes:           d["notes"]           as? String ?? ""
                    )
                }
                completion?()
            }
        }
    }

    func fetchLoadStats() {
        // Build name → clientID lookups for fallback matching on loads without a clientID
        let clientList = clients
        var nameToID: [String: String] = [:]
        var brokerToID: [String: String] = [:]
        for c in clientList {
            let cn = c.companyName.lowercased().trimmingCharacters(in: .whitespaces)
            if !cn.isEmpty { nameToID[cn] = c.id }
            let bn = c.brokerName.lowercased().trimmingCharacters(in: .whitespaces)
            if !bn.isEmpty { brokerToID[bn] = c.id }
        }

        Firestore.firestore().collection("loads")
            .whereField("status", isEqualTo: "Delivered")
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                var stats: [String: ClientLoadStats] = [:]
                for doc in docs {
                    let d = doc.data()
                    let rate = Double(d["rate"] as? String ?? "0") ?? 0
                    let clientID = d["clientID"] as? String ?? ""
                    let clientName = (d["clientName"] as? String ?? "")
                        .lowercased().trimmingCharacters(in: .whitespaces)
                    let brokerName = (d["brokerName"] as? String ?? "")
                        .lowercased().trimmingCharacters(in: .whitespaces)

                    // Resolve which client this load belongs to, in priority order
                    var matchedID: String? = nil
                    if !clientID.isEmpty { matchedID = clientID }
                    else if let id = nameToID[clientName], !clientName.isEmpty { matchedID = id }
                    else if let id = brokerToID[brokerName], !brokerName.isEmpty { matchedID = id }

                    guard let id = matchedID else { continue }
                    var cur = stats[id] ?? ClientLoadStats()
                    cur.count += 1
                    cur.revenue += rate
                    stats[id] = cur
                }
                DispatchQueue.main.async { loadStats = stats }
            }
    }
}

struct ClientStatPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.headline).foregroundColor(color)
            Text(title).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.12))
        .cornerRadius(10)
    }
}

// MARK: - Client Detail View
struct ClientDetailView: View {

    @Environment(\.dismiss) var dismiss
    let client: ClientInfo
    let stats: ClientLoadStats
    var onUpdate: (ClientInfo) -> Void

    @State private var isEditing = false
    @State private var companyName = ""
    @State private var brokerName = ""
    @State private var contactName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var accountingEmail = ""
    @State private var address = ""
    @State private var mc = ""
    @State private var dot = ""
    @State private var score = ""
    @State private var notes = ""
    @State private var isSaving = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            List {
                if isEditing {

                    // EDIT MODE
                    Section("Client Info") {
                        TextField("Company Name", text: $companyName)
                        TextField("Broker Name", text: $brokerName)
                        TextField("Contact Name", text: $contactName)
                    }

                    Section("Contact") {
                        TextField("Phone", text: $phone)
                            .keyboardType(.phonePad)
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        TextField("Accounting / Billing Email", text: $accountingEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        TextField("Address", text: $address)
                    }

                    Section("Regulatory") {
                        TextField("MC Number", text: $mc).keyboardType(.numberPad)
                        TextField("DOT Number", text: $dot).keyboardType(.numberPad)
                    }

                    Section("Performance") {
                        TextField("Score", text: $score)
                    }

                    Section("Notes") {
                        TextField("Internal notes...", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
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

                    // VIEW MODE
                    Section("Client Info") {
                        DetailRow(label: "Client ID",    value: client.id)
                        DetailRow(label: "Company Name", value: companyName)
                        DetailRow(label: "Broker Name",  value: brokerName)
                        if !contactName.isEmpty { DetailRow(label: "Contact",    value: contactName) }
                    }
                    Section("Contact") {
                        DetailRow(label: "Phone",             value: phone.isEmpty ? "—" : phone)
                        DetailRow(label: "Email",             value: email.isEmpty ? "—" : email)
                        if !accountingEmail.isEmpty { DetailRow(label: "Accounting Email", value: accountingEmail) }
                        DetailRow(label: "Address",           value: address.isEmpty ? "—" : address)
                    }
                    if !mc.isEmpty || !dot.isEmpty {
                        Section("Regulatory") {
                            if !mc.isEmpty  { DetailRow(label: "MC #",  value: mc)  }
                            if !dot.isEmpty { DetailRow(label: "DOT #", value: dot) }
                        }
                    }
                    Section("Performance") {
                        DetailRow(label: "Score", value: score.isEmpty ? "—" : score)
                    }
                    Section("Earnings") {
                        DetailRow(label: "Total Loads",  value: "\(stats.count)")
                        DetailRow(label: "Total Revenue", value: "$\(Int(stats.revenue))")
                    }
                    if !notes.isEmpty {
                        Section("Notes") {
                            Text(notes).font(.subheadline).foregroundColor(.secondary)
                        }
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
                            loadFields() // ✅ Reset any unsaved changes
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

    // MARK: - Load Fields
    func loadFields() {
        companyName     = client.companyName
        brokerName      = client.brokerName
        contactName     = client.contactName
        phone           = client.phone
        email           = client.email
        accountingEmail = client.accountingEmail
        address         = client.address
        mc              = client.mc
        dot             = client.dot
        score           = client.score
        notes           = client.notes
    }

    // MARK: - Save Changes
    func saveChanges() {
        guard !companyName.isEmpty else { errorMessage = "Company name cannot be empty."; return }
        isSaving = true; errorMessage = ""

        Firestore.firestore().collection("clients").document(client.id).updateData([
            "companyName":     companyName,
            "brokerName":      brokerName,
            "contactName":     contactName,
            "phone":           phone,
            "email":           email,
            "accountingEmail": accountingEmail,
            "address":         address,
            "mc":              mc,
            "dot":             dot,
            "score":           score,
            "notes":           notes,
            "updatedAt":       Timestamp()
        ]) { error in
            DispatchQueue.main.async {
                isSaving = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    let updated = ClientInfo(
                        id: client.id, companyName: companyName, brokerName: brokerName,
                        contactName: contactName, phone: phone, email: email,
                        accountingEmail: accountingEmail, address: address,
                        mc: mc, dot: dot, score: score, notes: notes
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
    @State private var isSaving = false

    var onAdd: (ClientInfo) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Company Info") {
                    TextField("Company Name", text: $companyName)
                    TextField("Broker Name", text: $brokerName)
                }
                Section("Contact") {
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Address", text: $address)
                }
                Section("Rating") {
                    TextField("Score (e.g. 5/5)", text: $score)
                }
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                    }
                }
                Section {
                    Button { saveClient() } label: {
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
            errorMessage = "Company name cannot be empty."
            return
        }

        isSaving = true
        errorMessage = ""

        // Check for duplicate company name
        Firestore.firestore()
            .collection("clients")
            .whereField("companyName", isEqualTo: companyName.trimmingCharacters(in: .whitespaces))
            .getDocuments { snapshot, _ in
                if let snapshot = snapshot, !snapshot.documents.isEmpty {
                    DispatchQueue.main.async {
                        errorMessage = "A client with this company name already exists."
                        isSaving = false
                    }
                    return
                }

                // No duplicate — save client
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
                    isSaving = false
                    onAdd(newClient)
                    dismiss()
                }
            }
    }
}
