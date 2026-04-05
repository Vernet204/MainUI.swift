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
    @EnvironmentObject private var appState: AppState

    @State private var loadID = ""
    @State private var pickup = ""
    @State private var delivery = ""
    @State private var weight = ""
    @State private var rate = ""
    @State private var status = "Unassigned"
    @State private var pickupDate = ""
    @State private var deliveryDate = ""
    @State private var pickupTime = ""
    @State private var deliveryTime = ""

    private let statuses = ["Unassigned", "Assigned", "In Transit", "Delivered"]

    var body: some View {
        NavigationStack {
            ScrollView {                          // ✅ opening brace added
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

                        TextField("Pickup Date", text: $pickupDate)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                        TextField("Pickup Time", text: $pickupTime)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                        TextField("Delivery Location", text: $delivery)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                        TextField("Delivery Date", text: $deliveryDate)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                        TextField("Delivery Time", text: $deliveryTime)
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
            }                                     // ✅ closing brace for ScrollView
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

        Firestore.firestore().collection("loads").addDocument(data: [
            "loadID": finalLoadID,
            "pickupLocation": pickup,
            "deliveryLocation": delivery,
            "weight": weight,
            "rate": rate,
            "status": status,
            "pickupDate": pickupDate,       // ✅ now saves actual input
            "dropoffDate": deliveryDate,    // ✅ now saves actual input
            "pickupTime": pickupTime,       // ✅ now saves actual input
            "deliveryTime": deliveryTime,   // ✅ now saves actual input
            "assignedDriver": "",
            "assignedVehicle": ""
        ])

        appState.loads.append(newLoad)
        dismiss()
    }
}

#Preview {
    CreateLoadView()
        .environmentObject(AppState())
}

