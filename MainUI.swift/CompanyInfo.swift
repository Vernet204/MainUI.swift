//
//  CompanyInfo.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 6/2/26.
//


//
//  CompanyInfoView.swift
//  MainUI.swift
//
//  Owner inputs company information used in invoices,
//  factoring sheets, and other documents.
//  Stored in Firestore under "company/info" document.
//

import SwiftUI
import FirebaseFirestore

struct CompanyInfo {
    var name:        String = "Good Partners Express LLC"
    var address:     String = ""
    var city:        String = ""
    var state:       String = ""
    var zip:         String = ""
    var phone:       String = ""
    var email:       String = ""
    var dotNumber:   String = ""
    var mcNumber:    String = ""
    var ein:         String = ""
    var clientNumber: String = "17780"  // TBS Factoring client number
    var factoringEmail: String = "schedulesls@loves.com"
    var ownerName:   String = ""

    var fullAddress: String {
        [address, city, state, zip].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    init() {}

    init(data: [String: Any]) {
        name         = data["name"]         as? String ?? "Good Partners Express LLC"
        address      = data["address"]      as? String ?? ""
        city         = data["city"]         as? String ?? ""
        state        = data["state"]        as? String ?? ""
        zip          = data["zip"]          as? String ?? ""
        phone        = data["phone"]        as? String ?? ""
        email        = data["email"]        as? String ?? ""
        dotNumber    = data["dotNumber"]    as? String ?? ""
        mcNumber     = data["mcNumber"]     as? String ?? ""
        ein          = data["ein"]          as? String ?? ""
        clientNumber = data["clientNumber"] as? String ?? "17780"
        factoringEmail = data["factoringEmail"] as? String ?? "schedulesls@loves.com"
        ownerName    = data["ownerName"]    as? String ?? ""
    }

    func toDictionary() -> [String: Any] {
        return [
            "name":           name,
            "address":        address,
            "city":           city,
            "state":          state,
            "zip":            zip,
            "phone":          phone,
            "email":          email,
            "dotNumber":      dotNumber,
            "mcNumber":       mcNumber,
            "ein":            ein,
            "clientNumber":   clientNumber,
            "factoringEmail": factoringEmail,
            "ownerName":      ownerName
        ]
    }
}

// MARK: - Company Info Service
class CompanyInfoService: ObservableObject {
    static let shared = CompanyInfoService()
    @Published var info = CompanyInfo()

    private let db = Firestore.firestore()
    private let docPath = "company/info"

    init() { fetch() }

    func fetch() {
        db.document(docPath).getDocument { snapshot, _ in
            guard let data = snapshot?.data() else { return }
            DispatchQueue.main.async {
                self.info = CompanyInfo(data: data)
            }
        }
    }

    func save(_ info: CompanyInfo, completion: @escaping (Bool) -> Void) {
        db.document(docPath).setData(info.toDictionary()) { error in
            DispatchQueue.main.async {
                if error == nil { self.info = info }
                completion(error == nil)
            }
        }
    }
}

// MARK: - Company Info View
struct CompanyInfoView: View {

    @Environment(\.dismiss) var dismiss
    @StateObject private var service = CompanyInfoService.shared

    @State private var name         = ""
    @State private var ownerName    = ""
    @State private var address      = ""
    @State private var city         = ""
    @State private var state        = ""
    @State private var zip          = ""
    @State private var phone        = ""
    @State private var email        = ""
    @State private var dotNumber    = ""
    @State private var mcNumber     = ""
    @State private var ein          = ""
    @State private var clientNumber = ""
    @State private var factoringEmail = ""

    @State private var isSaving = false
    @State private var saved = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {

                Section("Company Identity") {
                    TextField("Company Name", text: $name)
                    TextField("Owner / Authorized Signer Name", text: $ownerName)
                }

                Section("Address") {
                    TextField("Street Address", text: $address)
                    TextField("City", text: $city)
                    HStack {
                        TextField("State", text: $state)
                            .frame(maxWidth: 80)
                        TextField("ZIP Code", text: $zip)
                            .keyboardType(.numberPad)
                    }
                }

                Section("Contact") {
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                Section("Regulatory Numbers") {
                    TextField("DOT Number", text: $dotNumber)
                        .keyboardType(.numberPad)
                    TextField("MC Number", text: $mcNumber)
                        .keyboardType(.numberPad)
                    TextField("EIN / Tax ID", text: $ein)
                        .keyboardType(.numberPad)
                }

                Section("Factoring") {
                    TextField("TBS Client Number", text: $clientNumber)
                        .keyboardType(.numberPad)
                    TextField("Factoring Submit Email", text: $factoringEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    Text("Sheet is sent to this email by dispatcher")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                    }
                }

                if saved {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text("Company info saved successfully").foregroundColor(.green)
                        }
                    }
                }
            }
            .navigationTitle("Company Information")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { loadFields() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveInfo()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Save").fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }

    func loadFields() {
        let info    = service.info
        name        = info.name
        ownerName   = info.ownerName
        address     = info.address
        city        = info.city
        state       = info.state
        zip         = info.zip
        phone       = info.phone
        email       = info.email
        dotNumber   = info.dotNumber
        mcNumber    = info.mcNumber
        ein         = info.ein
        clientNumber = info.clientNumber
        factoringEmail = info.factoringEmail
    }

    func saveInfo() {
        guard !name.isEmpty else { errorMessage = "Company name is required."; return }
        isSaving = true
        errorMessage = ""
        saved = false

        var updated = CompanyInfo()
        updated.name          = name
        updated.ownerName     = ownerName
        updated.address       = address
        updated.city          = city
        updated.state         = state
        updated.zip           = zip
        updated.phone         = phone
        updated.email         = email
        updated.dotNumber     = dotNumber
        updated.mcNumber      = mcNumber
        updated.ein           = ein
        updated.clientNumber  = clientNumber
        updated.factoringEmail = factoringEmail

        service.save(updated) { success in
            isSaving = false
            if success {
                saved = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            } else {
                errorMessage = "Failed to save. Please try again."
            }
        }
    }
}

#Preview {
    CompanyInfoView()
}