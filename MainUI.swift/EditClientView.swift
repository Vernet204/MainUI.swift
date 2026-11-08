//
//  EditClientView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 6/3/26.
//


//
//  EditClientView.swift
//  MainUI.swift
//
//  Owner can view and edit full broker/client profile details.
//  Accessed from ClienteleView or anywhere clients are listed.
//

import SwiftUI
import FirebaseFirestore

struct EditClientView: View {

    let clientID: String
    @Environment(\.dismiss) var dismiss

    @State private var companyName    = ""
    @State private var brokerName     = ""
    @State private var contactName    = ""
    @State private var phone          = ""
    @State private var email          = ""
    @State private var accountingEmail = ""
    @State private var address        = ""
    @State private var city           = ""
    @State private var state          = ""
    @State private var zip            = ""
    @State private var mc             = ""
    @State private var dot            = ""
    @State private var notes          = ""

    @State private var isLoading  = true
    @State private var isSaving   = false
    @State private var saved      = false
    @State private var errorMsg   = ""

    var body: some View {
        NavigationStack {
            Form {
                if isLoading {
                    Section {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    }
                } else {

                    Section("Company") {
                        TextField("Company Name", text: $companyName)
                        TextField("Broker / DBA Name", text: $brokerName)
                    }

                    Section("Primary Contact") {
                        TextField("Contact Name", text: $contactName)
                        TextField("Phone Number", text: $phone)
                            .keyboardType(.phonePad)
                        TextField("Email Address", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                        TextField("Accounting / Billing Email", text: $accountingEmail)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }

                    Section("Address") {
                        TextField("Street Address", text: $address)
                        TextField("City", text: $city)
                        HStack {
                            TextField("State", text: $state).frame(maxWidth: 80)
                            TextField("ZIP", text: $zip).keyboardType(.numberPad)
                        }
                    }

                    Section("Regulatory") {
                        TextField("MC Number", text: $mc).keyboardType(.numberPad)
                        TextField("DOT Number", text: $dot).keyboardType(.numberPad)
                    }

                    Section("Notes") {
                        TextField("Internal notes about this client...", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    if !errorMsg.isEmpty {
                        Section {
                            Text(errorMsg).foregroundColor(.red).font(.caption)
                        }
                    }

                    if saved {
                        Section {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                Text("Client updated successfully").foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { saveClient() } label: {
                        if isSaving { ProgressView() }
                        else { Text("Save").fontWeight(.semibold) }
                    }
                    .disabled(isSaving || isLoading)
                }
            }
            .onAppear { loadClient() }
        }
    }

    // MARK: — Load from Firestore
    func loadClient() {
        Firestore.firestore().collection("clients").document(clientID).getDocument { snap, error in
            DispatchQueue.main.async {
                isLoading = false
                guard let d = snap?.data() else { errorMsg = "Could not load client."; return }
                companyName     = d["companyName"]     as? String ?? ""
                brokerName      = d["brokerName"]      as? String ?? ""
                contactName     = d["contactName"]     as? String ?? ""
                phone           = d["phone"]           as? String ?? ""
                email           = d["email"]           as? String ?? ""
                accountingEmail = d["accountingEmail"] as? String ?? ""
                address         = d["address"]         as? String ?? ""
                city            = d["city"]            as? String ?? ""
                state           = d["state"]           as? String ?? ""
                zip             = d["zip"]             as? String ?? ""
                mc              = d["mc"]              as? String ?? ""
                dot             = d["dot"]             as? String ?? ""
                notes           = d["notes"]           as? String ?? ""
            }
        }
    }

    // MARK: — Save to Firestore
    func saveClient() {
        guard !companyName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMsg = "Company name is required."
            return
        }
        isSaving = true
        errorMsg = ""
        saved = false

        Firestore.firestore().collection("clients").document(clientID).updateData([
            "companyName":     companyName.trimmingCharacters(in: .whitespaces),
            "brokerName":      brokerName,
            "contactName":     contactName,
            "phone":           phone,
            "email":           email,
            "accountingEmail": accountingEmail,
            "address":         address,
            "city":            city,
            "state":           state,
            "zip":             zip,
            "mc":              mc,
            "dot":             dot,
            "notes":           notes,
            "updatedAt":       Timestamp()
        ]) { error in
            DispatchQueue.main.async {
                isSaving = false
                if let error = error {
                    errorMsg = error.localizedDescription
                } else {
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
                }
            }
        }
    }
}