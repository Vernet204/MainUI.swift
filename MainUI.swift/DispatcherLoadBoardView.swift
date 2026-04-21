//
//  DispatcherLoadBoardView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/4/26.
//
import SwiftUI
import FirebaseFirestore

struct DispatcherLoadBoardView: View {

    @State private var loads: [LoadInfo] = []
    @State private var showCreateLoad = false
    @State private var selectedLoad: LoadInfo? = nil
    @State private var isLoading = true
    @State private var listener: ListenerRegistration? = nil
    @State private var filterStatus = "All"

    // ✅ Delivered excluded — lives in Load History
    let filters = ["All", "Unassigned", "Assigned", "Accepted", "Declined", "In Transit"]

    var body: some View {
        List {

            // MARK: - Filter Tabs
            Section {
                Picker("Filter", selection: $filterStatus) {
                    ForEach(filters, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            // MARK: - Stats Row
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        MiniStatCard(
                            title: "Unassigned",
                            value: "\(loads.filter { $0.status == "Unassigned" }.count)",
                            color: .orange
                        )
                        MiniStatCard(
                            title: "Assigned",
                            value: "\(loads.filter { $0.status == "Assigned" }.count)",
                            color: .blue
                        )
                        MiniStatCard(
                            title: "Accepted",
                            value: "\(loads.filter { $0.status == "Accepted" }.count)",
                            color: .green
                        )
                        MiniStatCard(
                            title: "Declined",
                            value: "\(loads.filter { $0.status == "Declined" }.count)",
                            color: .red
                        )
                        MiniStatCard(
                            title: "In Transit",
                            value: "\(loads.filter { $0.status == "In Transit" }.count)",
                            color: .purple
                        )
                    }
                }
            }

            // MARK: - Load List
            Section("Loads") {
                if isLoading {
                    ProgressView("Loading loads...")
                } else if filteredLoads.isEmpty {
                    ContentUnavailableView(
                        "No \(filterStatus == "All" ? "" : filterStatus) Loads",
                        systemImage: "tray",
                        description: Text(
                            filterStatus == "All"
                            ? "Create a load to get started."
                            : "No loads with status \"\(filterStatus)\"."
                        )
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
                                    Text(load.status)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(statusColor(load.status).opacity(0.15))
                                        .foregroundColor(statusColor(load.status))
                                        .clipShape(Capsule())

                                    Image(systemName: "pencil.circle")
                                        .foregroundColor(.gray)
                                        .font(.caption)
                                }

                                Divider()

                                Group {
                                    Label(
                                        "Pickup: \(load.pickupLocation)",
                                        systemImage: "mappin.circle"
                                    )
                                    Label(
                                        "Date & Time: \(load.pickupDateTime.formatted(date: .abbreviated, time: .shortened))",
                                        systemImage: "clock"
                                    )
                                    Label(
                                        "Dropoff: \(load.deliveryLocation)",
                                        systemImage: "mappin.and.ellipse"
                                    )
                                    Label(
                                        "Date & Time: \(load.deliveryDateTime.formatted(date: .abbreviated, time: .shortened))",
                                        systemImage: "clock.fill"
                                    )

                                    if !load.commodity.isEmpty {
                                        Label(
                                            "Cargo: \(load.commodity)",
                                            systemImage: "shippingbox"
                                        )
                                    }

                                    if !load.rate.isEmpty {
                                        Label(
                                            "Rate: $\(load.rate)",
                                            systemImage: "dollarsign.circle"
                                        )
                                        .foregroundColor(.green)
                                    }

                                    if !load.assignedDriver.isEmpty {
                                        Label(
                                            "Driver: \(load.assignedDriver)",
                                            systemImage: "person.fill"
                                        )
                                        .foregroundColor(.blue)
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .onDelete { indexSet in
                        let ids = indexSet.map { filteredLoads[$0].id }
                        loads.removeAll { ids.contains($0.id) }
                        ids.forEach { id in
                            Firestore.firestore()
                                .collection("loads")
                                .document(id)
                                .delete()
                        }
                    }
                }
            }
        }
        .navigationTitle("Load Board")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateLoad = true
                } label: {
                    Label("Add Load", systemImage: "plus")
                }
            }
        }
        .onAppear { startListening() }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
        .sheet(isPresented: $showCreateLoad) {
            CreateLoadView()
        }
        .sheet(item: $selectedLoad) { load in
            EditLoadView(load: load) {}
        }
    }

    // MARK: - Filter Logic
    var filteredLoads: [LoadInfo] {
        let withoutDelivered = loads.filter {
            $0.status.lowercased() != "delivered"
        }

        if filterStatus == "All" {
            return withoutDelivered.sorted { $0.pickupDateTime < $1.pickupDateTime }
        }

        return withoutDelivered
            .filter { $0.status == filterStatus }
            .sorted { $0.pickupDateTime < $1.pickupDateTime }
    }

    // MARK: - Status Color
    // ✅ Only defined once with all statuses
    func statusColor(_ status: String) -> Color {
        switch status {
        case "Unassigned": return .orange
        case "Assigned":   return .blue
        case "Accepted":   return .green
        case "Declined":   return .red
        case "In Transit": return .purple
        case "Delivered":  return .green
        default:           return .gray
        }
    }

    // MARK: - Real-time Listener
    func startListening() {
        listener?.remove()

        listener = Firestore.firestore()
            .collection("loads")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Load board error: \(error.localizedDescription)")
                    return
                }

                guard let docs = snapshot?.documents else { return }

                DispatchQueue.main.async {
                    loads = docs.compactMap { doc in
                        let d = doc.data()
                        let pickupDT = (d["pickupDateTime"] as? Timestamp)?.dateValue() ?? Date()
                        let deliveryDT = (d["deliveryDateTime"] as? Timestamp)?.dateValue() ?? Date()

                        return LoadInfo(
                            id: doc.documentID,
                            loadID: d["loadID"] as? String ?? doc.documentID,
                            pickupLocation: d["pickupLocation"] as? String ?? "",
                            deliveryLocation: d["deliveryLocation"] as? String ?? "",
                            pickupDateTime: pickupDT,
                            deliveryDateTime: deliveryDT,
                            status: d["status"] as? String ?? "Unassigned",
                            commodity: d["commodity"] as? String ?? "",
                            rate: d["rate"] as? String ?? "",
                            weight: d["weight"] as? String ?? "",
                            assignedDriver: d["assignedDriver"] as? String ?? ""
                        )
                    }
                    isLoading = false
                }
            }
    }
}

// MARK: - Mini Stat Card
// ✅ Outside the struct so it's accessible everywhere
struct MiniStatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(minWidth: 70)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}
