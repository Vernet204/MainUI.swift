//
//  LoadHistoryView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/14/26.
//


import SwiftUI
import FirebaseFirestore

struct LoadHistoryView: View {

    @State private var deliveredLoads: [HistoryLoad] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedLoad: HistoryLoad? = nil
    @State private var listener: ListenerRegistration? = nil

    var body: some View {
        List {

            // SEARCH BAR
            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search by Load ID, Driver, or Location", text: $searchText)
                        .autocorrectionDisabled()
                }
            }

            // SUMMARY STATS
            Section {
                HStack(spacing: 0) {

                    StatCard(
                        title: "Total Loads",
                        value: "\(deliveredLoads.count)",
                        color: .blue
                    )

                    Divider()

                    StatCard(
                        title: "Total Revenue",
                        value: totalRevenue,
                        color: .green
                    )
                }
                .frame(maxWidth: .infinity)
            }

            // LOAD LIST
            Section("Completed Loads") {
                if isLoading {
                    ProgressView("Loading history...")
                } else if filteredLoads.isEmpty {
                    ContentUnavailableView(
                        "No Completed Loads",
                        systemImage: "shippingbox",
                        description: Text("Delivered loads will appear here.")
                    )
                } else {
                    ForEach(filteredLoads) { load in
                        Button {
                            selectedLoad = load
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {

                                HStack {
                                    Text("Load ID: \(load.loadID)")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    // ✅ Delivered badge
                                    Text("Delivered")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundColor(.green)
                                        .clipShape(Capsule())
                                }

                                Label(
                                    "\(load.pickupLocation) → \(load.deliveryLocation)",
                                    systemImage: "arrow.right"
                                )
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                                HStack {
                                    Label(load.driverName, systemImage: "person.fill")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    Text(load.rate.isEmpty ? "Rate: —" : "Rate: $\(load.rate)")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.green)
                                }

                                if let deliveredAt = load.deliveredAt {
                                    Text("Delivered: \(deliveredAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Load History")
        .onAppear { startListening() }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
        // ✅ Pull to refresh
        .refreshable { startListening() }
        // ✅ Detail sheet on tap
        .sheet(item: $selectedLoad) { load in
            LoadHistoryDetailView(load: load)
        }
    }

    // MARK: - Search Filter
    var filteredLoads: [HistoryLoad] {
        if searchText.isEmpty {
            return deliveredLoads.sorted { ($0.deliveredAt ?? Date()) > ($1.deliveredAt ?? Date()) }
        }
        return deliveredLoads.filter {
            $0.loadID.localizedCaseInsensitiveContains(searchText) ||
            $0.driverName.localizedCaseInsensitiveContains(searchText) ||
            $0.pickupLocation.localizedCaseInsensitiveContains(searchText) ||
            $0.deliveryLocation.localizedCaseInsensitiveContains(searchText)
        }
        .sorted { ($0.deliveredAt ?? Date()) > ($1.deliveredAt ?? Date()) }
    }

    // MARK: - Total Revenue
    var totalRevenue: String {
        let total = deliveredLoads.compactMap { Double($0.rate) }.reduce(0, +)
        return String(format: "$%.2f", total)
    }

    // MARK: - Real-time Listener
    func startListening() {
        isLoading = true
        listener?.remove()

        listener = Firestore.firestore()
            .collection("loads")
            .whereField("status", isEqualTo: "Delivered")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Load history error: \(error.localizedDescription)")
                    return
                }

                guard let docs = snapshot?.documents else { return }

                DispatchQueue.main.async {
                    deliveredLoads = docs.map { doc in
                        let d = doc.data()
                        return HistoryLoad(
                            id: doc.documentID,
                            loadID: d["loadID"] as? String ?? doc.documentID,
                            pickupLocation: d["pickupLocation"] as? String ?? "",
                            deliveryLocation: d["deliveryLocation"] as? String ?? "",
                            pickupDate: d["pickupDate"] as? String ?? "—",
                            dropoffDate: d["dropoffDate"] as? String ?? "—",
                            driverName: d["deliveredBy"] as? String ?? d["assignedDriver"] as? String ?? "—",
                            vehicleUnit: d["assignedVehicle"] as? String ?? "—",
                            rate: d["rate"] as? String ?? "",
                            weight: d["weight"] as? String ?? "—",
                            deliveredAt: (d["deliveredAt"] as? Timestamp)?.dateValue()
                        )
                    }
                    isLoading = false
                }
            }
    }
}

// MARK: - Load History Detail View
struct LoadHistoryDetailView: View {

    @Environment(\.dismiss) var dismiss
    let load: HistoryLoad

    var body: some View {
        NavigationStack {
            List {

                Section("Load Info") {
                    DetailRow(label: "Load ID", value: load.loadID)
                    DetailRow(label: "Status", value: "Delivered ✅")
                    if let deliveredAt = load.deliveredAt {
                        DetailRow(
                            label: "Delivered At",
                            value: deliveredAt.formatted(date: .long, time: .shortened)
                        )
                    }
                }

                Section("Route") {
                    DetailRow(label: "Pickup", value: load.pickupLocation)
                    DetailRow(label: "Pickup Date", value: load.pickupDate)
                    DetailRow(label: "Delivery", value: load.deliveryLocation)
                    DetailRow(label: "Delivery Date", value: load.dropoffDate)
                }

                Section("Driver & Vehicle") {
                    DetailRow(label: "Driver", value: load.driverName)
                    DetailRow(label: "Vehicle Unit", value: load.vehicleUnit)
                }

                Section("Load Details") {
                    DetailRow(label: "Weight", value: load.weight.isEmpty ? "—" : "\(load.weight) lbs")
                    DetailRow(label: "Rate", value: load.rate.isEmpty ? "—" : "$\(load.rate)")
                }
            }
            .navigationTitle("Load \(load.loadID)")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - HistoryLoad Model
struct HistoryLoad: Identifiable {
    let id: String
    var loadID: String
    var pickupLocation: String
    var deliveryLocation: String
    var pickupDate: String
    var dropoffDate: String
    var driverName: String
    var vehicleUnit: String
    var rate: String
    var weight: String
    var deliveredAt: Date?
}
