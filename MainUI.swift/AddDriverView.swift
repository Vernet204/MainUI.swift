//
//  AddDriverView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/7/26.
//


import SwiftUI

struct AddDriverView: View {

    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var status = "Active"

    var onAdd: (Driver) -> Void

    var body: some View {

        NavigationStack {

            Form {

                TextField("Driver Name", text: $name)

                TextField("Email", text: $email)

                Picker("Status", selection: $status) {
                    Text("Active").tag("Active")
                    Text("Inactive").tag("Inactive")
                }
            }

            .navigationTitle("Add Driver")

            .toolbar {

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {

                    Button("Add") {

                        let driver = Driver(
                            name: name,
                            email: email,
                            status: status
                        )

                        onAdd(driver)
                        dismiss()
                    }
                }
            }
        }
    }
}
