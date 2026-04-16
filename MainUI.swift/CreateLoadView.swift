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

    @State private var loadID = ""
    @State private var pickup = ""
    @State private var delivery = ""
    @State private var weight = ""
    @State private var rate = ""
    @State private var pickupDateTime = Date()
    @State private var deliveryDateTime = Date().addingTimeInterval(3600 * 8)
    @State private var commodity = ""
    @State private var specialInstructions = ""
    @State private var errorMessage = ""
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // LOAD INFO
                    FormCard(title: "Load Info") {
                        VStack(spacing: 12) {
                            TextField("Load ID (Ex: LD-1003)", text: $loadID)
                                .textInputAutocapitalization(.characters)
                                .textFieldStyle(.roundedBorder)

                            TextField("Commodity / Cargo Type", text: $commodity)
                                .textFieldStyle(.roundedBorder)

                            TextField("Weight (lbs)", text: $weight)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)

                            TextField("Rate ($)", text: $rate)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // PICKUP
                    FormCard(title: "📍 Pickup") {
                        VStack(spacing: 12) {
                            TextField("Pickup Location", text: $pickup)
                                .textFieldStyle(.roundedBorder)

                            DatePicker(
                                "Pickup Date & Time",
                                selection: $pickupDateTime,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .onChange(of: pickupDateTime) { newValue in
                                if deliveryDateTime <= newValue {
                                    deliveryDateTime = newValue.addingTimeInterval(3600 * 4)
                                }
                            }
                        }
                    }

                    // DELIVERY
                    FormCard(title: "🏁 Delivery") {
                        VStack(spacing: 12) {
                            TextField("Delivery Location", text: $delivery)
                                .textFieldStyle(.roundedBorder)

                            DatePicker(
                                "Delivery Date & Time",
                                selection: $deliveryDateTime,
                                in: pickupDateTime...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                        }
                    }

                    // SPECIAL INSTRUCTIONS
                    FormCard(title: "📋 Special Instructions") {
                        TextField(
                            "Any special requirements...",
                            text: $specialInstructions,
                            axis: .vertical
                        )
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                    }

                    // ✅ Duration preview
                    if !pickup.isEmpty && !delivery.isEmpty {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.blue)
                            Text("Estimated duration: \(estimatedDuration)")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button(action: createLoad) {
                        if isCreating {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
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
                    }
                    .disabled(isCreating)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Create Load")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .disabled(isCreating)
                }
            }
        }
    }

    // MARK: - Estimated Duration
    var estimatedDuration: String {
        let diff = deliveryDateTime.timeIntervalSince(pickupDateTime)
        let hours = Int(diff / 3600)
        let minutes = Int((diff.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }

    // MARK: - Create Load
    func createLoad() {
        guard !pickup.isEmpty else { errorMessage = "Enter pickup location."; return }
        guard !delivery.isEmpty else { errorMessage = "Enter delivery location."; return }
        guard !rate.isEmpty else { errorMessage = "Enter rate."; return }
        guard deliveryDateTime > pickupDateTime else {
            errorMessage = "Delivery must be after pickup."
            return
        }

        let finalLoadID = loadID.isEmpty
            ? "LD-\(Int.random(in: 1000...9999))"
            : loadID.uppercased().trimmingCharacters(in: .whitespaces)

        isCreating = true
        errorMessage = ""

        Firestore.firestore()
            .collection("loads")
            .whereField("loadID", isEqualTo: finalLoadID)
            .getDocuments { snapshot, error in
                if let snapshot = snapshot, !snapshot.documents.isEmpty {
                    DispatchQueue.main.async {
                        errorMessage = "Load ID \(finalLoadID) already exists."
                        isCreating = false
                    }
                    return
                }

                Firestore.firestore().collection("loads").addDocument(data: [
                    "loadID": finalLoadID,
                    "pickupLocation": pickup.trimmingCharacters(in: .whitespaces),
                    "deliveryLocation": delivery.trimmingCharacters(in: .whitespaces),
                    "pickupDateTime": Timestamp(date: pickupDateTime),
                    "deliveryDateTime": Timestamp(date: deliveryDateTime),
                    "weight": weight,
                    "rate": rate,
                    "commodity": commodity,
                    "specialInstructions": specialInstructions,
                    "status": "Unassigned",
                    "assignedDriver": "",
                    "assignedDriverID": "",
                    "assignedVehicle": "",
                    "createdAt": Timestamp()
                ]) { error in
                    DispatchQueue.main.async {
                        isCreating = false
                        if let error = error {
                            errorMessage = error.localizedDescription
                        } else {
                            dismiss()
                        }
                    }
                }
            }
    }
}

// MARK: - Form Card
struct FormCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
        .padding(.horizontal)
    }
}

#Preview {
    CreateLoadView()
}
