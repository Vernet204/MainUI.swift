//
//  CreateLoadView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/15/26.
//

import SwiftUI

struct CreateLoadView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    @State private var loadID = ""
    @State private var pickup = ""
    @State private var delivery = ""
    @State private var weight = ""
    @State private var rate = ""
    @State private var status = "Unassigned"

    private let statuses = ["Unassigned", "Assigned", "In Transit", "Delivered"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                Text("Create New Load")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 15) {

                    TextField("Load ID (Ex: LD-1003)", text: $loadID)
                        .textInputAutocapitalization(.characters)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    TextField("Pickup Location", text: $pickup)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    TextField("Delivery Location", text: $delivery)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    TextField("Load Weight (lbs)", text: $weight)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    TextField("Rate ($)", text: $rate)
                        .keyboardType(.decimalPad)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.headline)

                        Picker("Status", selection: $status) {
                            ForEach(statuses, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.menu)
                    }
                }
                .padding(.horizontal)

                Button(action: addLoad) {
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
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Create Load")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func addLoad() {
        let finalLoadID = loadID.isEmpty ? "LD-\(Int.random(in: 1000...9999))" : loadID

        let newLoad = Load(
            loadID: finalLoadID,
            pickup: pickup,
            delivery: delivery,
            weight: weight,
            rate: rate,
            status: status
        )

        appState.loads.append(newLoad)
        dismiss()
    }
}

#Preview {
    CreateLoadView()
        .environmentObject(AppState())
}


