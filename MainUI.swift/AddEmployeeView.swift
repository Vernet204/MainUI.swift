//
//  AddEmployeeView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/4/26.
//


import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseCore

struct AddEmployeeView: View {

    @Environment(\.dismiss) var dismiss

    @State private var fullName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var selectedRole = "Driver"
    @State private var tempPassword = ""
    @State private var errorMessage = ""

    let roles = ["Driver", "Dispatcher"]
    var onAdd: (Employee) -> Void

    // ✅ Secondary Firebase app to create users without affecting owner session
    private var secondaryApp: FirebaseApp? {
        if FirebaseApp.app(name: "Secondary") == nil {
            let options = FirebaseApp.app()!.options
            FirebaseApp.configure(name: "Secondary", options: options)
        }
        return FirebaseApp.app(name: "Secondary")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Employee Info") {
                    TextField("Full Name", text: $fullName)
                    TextField("Phone Number", text: $phone)
                        .keyboardType(.phonePad)
                    TextField("Email Address", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    SecureField("Temporary Password", text: $tempPassword)
                }

                Section("Role") {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(roles, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Employee")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { createEmployee() }
                }
            }
        }
    }

    func createEmployee() {
        guard !fullName.isEmpty else { errorMessage = "Enter full name."; return }
        guard !email.isEmpty else { errorMessage = "Enter email."; return }
        guard tempPassword.count >= 6 else { errorMessage = "Password must be 6+ characters."; return }

        // ✅ Use secondary app so owner stays logged in
        guard let secondary = secondaryApp else { return }
        let secondaryAuth = Auth.auth(app: secondary)

        secondaryAuth.createUser(withEmail: email, password: tempPassword) { result, error in
            if let error = error {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                }
                return
            }

            guard let uid = result?.user.uid else { return }

            // Save to Firestore
            Firestore.firestore().collection("users").document(uid).setData([
                "name": fullName,
                "email": email,
                "phone": phone,
                "role": selectedRole,
                "firstLogin": true
            ])

            // Sign out of secondary app — owner session untouched
            try? secondaryAuth.signOut()

            DispatchQueue.main.async {
                let newEmployee = Employee(
                    name: fullName,
                    role: selectedRole,
                    hireDate: Date(),
                    Email: email
                )
                onAdd(newEmployee)
                dismiss()
            }
        }
    }
}
