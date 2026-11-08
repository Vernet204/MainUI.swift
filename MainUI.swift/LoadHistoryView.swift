//
//  LoadHistoryView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/14/26.
//

import SwiftUI
import FirebaseFirestore

// MARK: - Time Period Filter
enum TimePeriod: String, CaseIterable {
    case today    = "Today"
    case week     = "This Week"
    case month    = "This Month"
    case year     = "This Year"
    case allTime  = "All Time"

    // Returns the start date for this period using Calendar
    // so "This Week" resets on Monday, "This Month" on the 1st, etc.
    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()
        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .week:
            return calendar.date(
                from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            )
        case .month:
            return calendar.date(
                from: calendar.dateComponents([.year, .month], from: now)
            )
        case .year:
            return calendar.date(
                from: calendar.dateComponents([.year], from: now)
            )
        case .allTime:
            return nil
        }
    }
}

struct LoadHistoryView: View {

    @State private var deliveredLoads: [HistoryLoad] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var selectedLoad: HistoryLoad? = nil
    @State private var listener: ListenerRegistration? = nil
    // Default to All Time so existing behaviour is preserved
    @State private var selectedPeriod: TimePeriod = .allTime

    var body: some View {
        List {

            // MARK: - Time Period Filter
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TimePeriod.allCases, id: \.self) { period in
                            Button {
                                selectedPeriod = period
                            } label: {
                                Text(period.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        selectedPeriod == period
                                        ? Color.blue
                                        : Color(.systemGray5)
                                    )
                                    .foregroundColor(
                                        selectedPeriod == period ? .white : .primary
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: - Search Bar
            Section {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundColor(.gray)
                    TextField("Search by Load ID, Driver, or Location", text: $searchText)
                        .autocorrectionDisabled()
                }
            }

            // MARK: - Summary Stats (reflect current filter + search)
            Section {
                HStack(spacing: 0) {
                    StatCard(
                        title: "Total Loads",
                        value: "\(filteredLoads.count)",
                        color: .blue
                    )
                    Divider()
                    StatCard(
                        title: periodRevenueLabel,
                        value: filteredRevenue,
                        color: .green
                    )
                }
                .frame(maxWidth: .infinity)
            }

            // MARK: - Load List
            Section(sectionHeader) {
                if isLoading {
                    ProgressView("Loading history...")
                } else if filteredLoads.isEmpty {
                    ContentUnavailableView(
                        "No Loads Found",
                        systemImage: "shippingbox",
                        description: Text(emptyMessage)
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
                                    Text("Delivered")
                                        .font(.caption).fontWeight(.semibold)
                                        .padding(.horizontal, 8).padding(.vertical, 4)
                                        .background(Color.green.opacity(0.15))
                                        .foregroundColor(.green)
                                        .clipShape(Capsule())
                                }

                                Label(
                                    "\(load.pickupLocation) → \(load.deliveryLocation)",
                                    systemImage: "arrow.right"
                                )
                                .font(.subheadline).foregroundColor(.secondary)

                                if load.stops.count > 2 {
                                    Label("\(load.stops.count) stops",
                                          systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                                        .font(.caption).fontWeight(.semibold)
                                        .foregroundColor(.purple)
                                }

                                HStack {
                                    Label(load.driverName, systemImage: "person.fill")
                                        .font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    Text(load.rate.isEmpty ? "Rate: —" : "Rate: $\(load.rate)")
                                        .font(.caption).fontWeight(.semibold).foregroundColor(.green)
                                }

                                if let deliveredAt = load.deliveredAt {
                                    Text("Delivered: \(deliveredAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption).foregroundColor(.secondary)
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
        .refreshable { startListening() }
        .sheet(item: $selectedLoad) { load in
            LoadHistoryDetailView(load: load)
        }
    }

    // MARK: - Filtered Loads
    //  Combines period filter + search — both work together
    var filteredLoads: [HistoryLoad] {
        var result = deliveredLoads

        // Apply time period filter
        if let start = selectedPeriod.startDate {
            result = result.filter { load in
                guard let deliveredAt = load.deliveredAt else { return false }
                return deliveredAt >= start
            }
        }

        // Apply search filter on top
        if !searchText.isEmpty {
            result = result.filter {
                $0.loadID.localizedCaseInsensitiveContains(searchText) ||
                $0.driverName.localizedCaseInsensitiveContains(searchText) ||
                $0.pickupLocation.localizedCaseInsensitiveContains(searchText) ||
                $0.deliveryLocation.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result.sorted { ($0.deliveredAt ?? Date()) > ($1.deliveredAt ?? Date()) }
    }

    // MARK: - Revenue for filtered period only
    var filteredRevenue: String {
        let total = filteredLoads.compactMap { Double($0.rate) }.reduce(0, +)
        return String(format: "$%.2f", total)
    }

    //  Revenue label changes to match selected period
    var periodRevenueLabel: String {
        switch selectedPeriod {
        case .today:   return "Today's Revenue"
        case .week:    return "Week's Revenue"
        case .month:   return "Month's Revenue"
        case .year:    return "Year's Revenue"
        case .allTime: return "Total Revenue"
        }
    }

    //  Section header reflects the active filter
    var sectionHeader: String {
        switch selectedPeriod {
        case .today:   return "Delivered Today"
        case .week:    return "Delivered This Week"
        case .month:   return "Delivered This Month"
        case .year:    return "Delivered This Year"
        case .allTime: return "All Completed Loads"
        }
    }

    //  Empty state message reflects active filter
    var emptyMessage: String {
        if !searchText.isEmpty {
            return "No loads match your search in this period."
        }
        switch selectedPeriod {
        case .today:   return "No loads were delivered today."
        case .week:    return "No loads delivered this week yet."
        case .month:   return "No loads delivered this month yet."
        case .year:    return "No loads delivered this year yet."
        case .allTime: return "Delivered loads will appear here."
        }
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
                            stops: Load.decodeStops(from: d),
                            driverName: d["deliveredBy"] as? String
                                ?? d["assignedDriver"] as? String ?? "—",
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
                    if load.stops.isEmpty {
                        Text("No stops on file").foregroundColor(.secondary).font(.caption)
                    } else {
                        ForEach(Array(load.stops.enumerated()), id: \.element.id) { index, stop in
                            StopRow(index: index + 1, stop: stop)
                        }
                    }
                }

                Section("Driver & Vehicle") {
                    DetailRow(label: "Driver", value: load.driverName)
                    DetailRow(label: "Vehicle Unit", value: load.vehicleUnit)
                }

                Section("Load Details") {
                    DetailRow(
                        label: "Weight",
                        value: load.weight.isEmpty ? "—" : "\(load.weight) lbs"
                    )
                    DetailRow(
                        label: "Rate",
                        value: load.rate.isEmpty ? "—" : "$\(load.rate)"
                    )
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
                .font(.title2).fontWeight(.bold).foregroundColor(color)
            Text(title)
                .font(.caption).foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

// MARK: - HistoryLoad Model
struct HistoryLoad: Identifiable {
    let id: String
    var loadID: String
    var stops: [Stop]
    var driverName: String
    var vehicleUnit: String
    var rate: String
    var weight: String
    var deliveredAt: Date?

    var pickupLocation: String   { stops.firstPickup?.address ?? "" }
    var deliveryLocation: String { stops.lastDelivery?.address ?? "" }
    var pickupDate: String {
        guard let dt = stops.firstPickup?.datetime else { return "—" }
        return dt.formatted(date: .abbreviated, time: .shortened)
    }
    var dropoffDate: String {
        guard let dt = stops.lastDelivery?.datetime else { return "—" }
        return dt.formatted(date: .abbreviated, time: .shortened)
    }
}
