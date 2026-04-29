//
//  PerformanceView.swift
//  MainUI.swift
//
//  Company Performance — Drivers, Dispatchers, Vehicles
//  Accessible from OwnerDashboardView
//

import SwiftUI
import FirebaseFirestore

// MARK: - Models

struct DriverPerformance: Identifiable {
    let id: String
    var driverName: String
    var totalDelivered: Int
    var totalDeclined: Int
    var totalRevenue: Double
    var onTimeCount: Int
    var lateCount: Int
    var avgLoadDurationHours: Double

    var onTimeRate: Double {
        guard totalDelivered > 0 else { return 0 }
        return Double(onTimeCount) / Double(totalDelivered) * 100
    }
    var declinedRate: Double {
        let total = totalDelivered + totalDeclined
        guard total > 0 else { return 0 }
        return Double(totalDeclined) / Double(total) * 100
    }
    var avgRevenuePerLoad: Double {
        guard totalDelivered > 0 else { return 0 }
        return totalRevenue / Double(totalDelivered)
    }
}

struct DispatcherPerformance: Identifiable {
    let id: String
    var dispatcherName: String
    var loadsCreated: Int
    var loadsAssigned: Int
    var loadsReassigned: Int
    var avgAssignTimeHours: Double
    var totalRevenueManagedUSD: Double

    var reassignRate: Double {
        guard loadsAssigned > 0 else { return 0 }
        return Double(loadsReassigned) / Double(loadsAssigned) * 100
    }
}

struct VehiclePerformance: Identifiable {
    let id: String
    var unitNumber: String
    var plate: String
    var tripsCompleted: Int
    var totalRevenue: Double
    var maintenanceCount: Int
    var inspectionsPassed: Int
    var inspectionsFailed: Int
    var assignedDriverName: String
    var currentStatus: String

    var inspectionPassRate: Double {
        let total = inspectionsPassed + inspectionsFailed
        guard total > 0 else { return 0 }
        return Double(inspectionsPassed) / Double(total) * 100
    }
    var avgRevenuePerTrip: Double {
        guard tripsCompleted > 0 else { return 0 }
        return totalRevenue / Double(tripsCompleted)
    }
}


// MARK: - Main Performance View

struct PerformanceView: View {

    enum PerformanceTab: String, CaseIterable {
        case drivers     = "Drivers"
        case dispatchers = "Dispatchers"
        case vehicles    = "Vehicles"
    }

    enum DriverSortOption: String, CaseIterable {
        case deliveries = "Deliveries"
        case revenue    = "Revenue"
        case onTime     = "On-Time %"
        case declined   = "Decline %"
    }

    enum DispatcherSortOption: String, CaseIterable {
        case loadsCreated  = "Created"
        case loadsAssigned = "Assigned"
        case revenue       = "Revenue"
        case reassignRate  = "Reassign %"
    }

    enum VehicleSortOption: String, CaseIterable {
        case trips    = "Trips"
        case revenue  = "Revenue"
        case passRate = "Pass Rate"
    }

    @State private var selectedTab: PerformanceTab = .drivers

    @State private var drivers: [DriverPerformance] = []
    @State private var driversLoading = true
    @State private var driverSort: DriverSortOption = .deliveries

    @State private var dispatchers: [DispatcherPerformance] = []
    @State private var dispatchersLoading = true
    @State private var dispatcherSort: DispatcherSortOption = .loadsCreated

    @State private var vehicles: [VehiclePerformance] = []
    @State private var vehiclesLoading = true
    @State private var vehicleSort: VehicleSortOption = .trips

    @State private var selectedDriver: DriverPerformance? = nil
    @State private var selectedDispatcher: DispatcherPerformance? = nil
    @State private var selectedVehicle: VehiclePerformance? = nil

    var fleetRevenue: Double {
        drivers.reduce(0) { $0 + $1.totalRevenue }
    }
    var fleetDeliveries: Int {
        drivers.reduce(0) { $0 + $1.totalDelivered }
    }
    var fleetOnTimeRate: Double {
        let delivered = drivers.reduce(0) { $0 + $1.totalDelivered }
        let onTime    = drivers.reduce(0) { $0 + $1.onTimeCount }
        guard delivered > 0 else { return 0 }
        return Double(onTime) / Double(delivered) * 100
    }

    var sortedDrivers: [DriverPerformance] {
        switch driverSort {
        case .deliveries: return drivers.sorted { $0.totalDelivered > $1.totalDelivered }
        case .revenue:    return drivers.sorted { $0.totalRevenue > $1.totalRevenue }
        case .onTime:     return drivers.sorted { $0.onTimeRate > $1.onTimeRate }
        case .declined:   return drivers.sorted { $0.declinedRate < $1.declinedRate }
        }
    }

    var sortedDispatchers: [DispatcherPerformance] {
        switch dispatcherSort {
        case .loadsCreated:  return dispatchers.sorted { $0.loadsCreated > $1.loadsCreated }
        case .loadsAssigned: return dispatchers.sorted { $0.loadsAssigned > $1.loadsAssigned }
        case .revenue:       return dispatchers.sorted { $0.totalRevenueManagedUSD > $1.totalRevenueManagedUSD }
        case .reassignRate:  return dispatchers.sorted { $0.reassignRate < $1.reassignRate }
        }
    }

    var sortedVehicles: [VehiclePerformance] {
        switch vehicleSort {
        case .trips:    return vehicles.sorted { $0.tripsCompleted > $1.tripsCompleted }
        case .revenue:  return vehicles.sorted { $0.totalRevenue > $1.totalRevenue }
        case .passRate: return vehicles.sorted { $0.inspectionPassRate > $1.inspectionPassRate }
        }
    }

    var body: some View {
        List {

            // MARK: - Tab Picker
            Section {
                Picker("Section", selection: $selectedTab) {
                    ForEach(PerformanceTab.allCases, id: \.self) {
                        Text($0.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            // ── DRIVERS
            if selectedTab == .drivers {

                Section("Fleet Overview") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        PerfStatCard(value: "\(fleetDeliveries)",
                                     label: "Delivered", color: .green)
                        PerfStatCard(value: "$\(Int(fleetRevenue))",
                                     label: "Revenue", color: .blue)
                        PerfStatCard(
                            value: String(format: "%.0f%%", fleetOnTimeRate),
                            label: "On-Time",
                            color: fleetOnTimeRate >= 80 ? .green
                                 : fleetOnTimeRate >= 60 ? .orange : .red
                        )
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    Picker("Sort", selection: $driverSort) {
                        ForEach(DriverSortOption.allCases, id: \.self) {
                            Text($0.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Drivers") {
                    if driversLoading {
                        centeredProgress("Calculating driver performance...")
                    } else if drivers.isEmpty {
                        centeredEmpty("No delivered loads yet.")
                    } else {
                        ForEach(Array(sortedDrivers.enumerated()), id: \.element.id) { i, d in
                            Button { selectedDriver = d } label: {
                                DriverPerfRow(driver: d, rank: i + 1)
                            }
                        }
                    }
                }
            }

            // ── DISPATCHERS ─
            if selectedTab == .dispatchers {

                Section("Dispatch Overview") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        PerfStatCard(
                            value: "\(dispatchers.reduce(0) { $0 + $1.loadsCreated })",
                            label: "Created", color: .blue
                        )
                        PerfStatCard(
                            value: "\(dispatchers.reduce(0) { $0 + $1.loadsAssigned })",
                            label: "Assigned", color: .purple
                        )
                        PerfStatCard(
                            value: "$\(Int(dispatchers.reduce(0) { $0 + $1.totalRevenueManagedUSD }))",
                            label: "Managed", color: .green
                        )
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    Picker("Sort", selection: $dispatcherSort) {
                        ForEach(DispatcherSortOption.allCases, id: \.self) {
                            Text($0.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Dispatchers") {
                    if dispatchersLoading {
                        centeredProgress("Calculating dispatcher performance...")
                    } else if dispatchers.isEmpty {
                        centeredEmpty("No dispatcher data yet.\nStats populate as dispatchers create and assign loads.")
                    } else {
                        ForEach(Array(sortedDispatchers.enumerated()), id: \.element.id) { i, d in
                            Button { selectedDispatcher = d } label: {
                                DispatcherPerfRow(dispatcher: d, rank: i + 1)
                            }
                        }
                    }
                }
            }

            // ── VEHICLES
            if selectedTab == .vehicles {

                Section("Fleet Overview") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        PerfStatCard(
                            value: "\(vehicles.reduce(0) { $0 + $1.tripsCompleted })",
                            label: "Total Trips", color: .blue
                        )
                        PerfStatCard(
                            value: "$\(Int(vehicles.reduce(0) { $0 + $1.totalRevenue }))",
                            label: "Revenue", color: .green
                        )
                        PerfStatCard(
                            value: "\(vehicles.reduce(0) { $0 + $1.maintenanceCount })",
                            label: "Maint. Records", color: .orange
                        )
                    }
                    .padding(.vertical, 6)
                }

                Section {
                    Picker("Sort", selection: $vehicleSort) {
                        ForEach(VehicleSortOption.allCases, id: \.self) {
                            Text($0.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Vehicles") {
                    if vehiclesLoading {
                        centeredProgress("Calculating vehicle performance...")
                    } else if vehicles.isEmpty {
                        centeredEmpty("No vehicle data yet.")
                    } else {
                        ForEach(Array(sortedVehicles.enumerated()), id: \.element.id) { i, v in
                            Button { selectedVehicle = v } label: {
                                VehiclePerfRow(vehicle: v, rank: i + 1)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Company Performance")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            fetchDriverPerformance()
            fetchDispatcherPerformance()
            fetchVehiclePerformance()
        }
        .refreshable {
            fetchDriverPerformance()
            fetchDispatcherPerformance()
            fetchVehiclePerformance()
        }
        .sheet(item: $selectedDriver)     { DriverPerformanceDetailView(driver: $0) }
        .sheet(item: $selectedDispatcher) { DispatcherPerformanceDetailView(dispatcher: $0) }
        .sheet(item: $selectedVehicle)    { VehiclePerformanceDetailView(vehicle: $0) }
    }

    // MARK: - Inline helpers
    @ViewBuilder
    func centeredProgress(_ label: String) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                Text(label).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    func centeredEmpty(_ message: String) -> some View {
        Text(message)
            .font(.caption).foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity).padding()
    }

    
    // MARK: - Fetch Driver Performance
    
    func fetchDriverPerformance() {
        driversLoading = true
        Firestore.firestore().collection("loads").getDocuments { snapshot, _ in
            guard let docs = snapshot?.documents else {
                DispatchQueue.main.async { driversLoading = false }
                return
            }
            var map: [String: DriverPerformance] = [:]
            for doc in docs {
                let d          = doc.data()
                let status     = d["status"] as? String ?? ""
                let driverName = d["assignedDriver"] as? String ?? ""
                if driverName.isEmpty { continue }
                let rate        = Double(d["rate"] as? String ?? "0") ?? 0
                let deliveredAt = (d["deliveredAt"] as? Timestamp)?.dateValue()
                let scheduledDT = (d["deliveryDateTime"] as? Timestamp)?.dateValue()
                let pickupDT    = (d["pickupDateTime"] as? Timestamp)?.dateValue()
                if map[driverName] == nil {
                    map[driverName] = DriverPerformance(
                        id: driverName, driverName: driverName,
                        totalDelivered: 0, totalDeclined: 0,
                        totalRevenue: 0, onTimeCount: 0,
                        lateCount: 0, avgLoadDurationHours: 0
                    )
                }
                switch status.lowercased() {
                case "delivered":
                    map[driverName]!.totalDelivered += 1
                    map[driverName]!.totalRevenue   += rate
                    if let da = deliveredAt, let sched = scheduledDT {
                        if da <= sched { map[driverName]!.onTimeCount += 1 }
                        else           { map[driverName]!.lateCount   += 1 }
                    }
                    if let pickup = pickupDT, let da = deliveredAt {
                        let hours = da.timeIntervalSince(pickup) / 3600
                        let count = Double(map[driverName]!.totalDelivered)
                        let prev  = map[driverName]!.avgLoadDurationHours
                        map[driverName]!.avgLoadDurationHours = (prev * (count - 1) + hours) / count
                    }
                case "declined":
                    map[driverName]!.totalDeclined += 1
                default: break
                }
            }
            DispatchQueue.main.async {
                drivers = Array(map.values)
                driversLoading = false
            }
        }
    }

    
    // MARK: - Fetch Dispatcher Performance
    
    func fetchDispatcherPerformance() {
        dispatchersLoading = true
        Firestore.firestore().collection("loads").getDocuments { snapshot, _ in
            guard let docs = snapshot?.documents else {
                DispatchQueue.main.async { dispatchersLoading = false }
                return
            }
            var map: [String: DispatcherPerformance] = [:]
            for doc in docs {
                let d            = doc.data()
                let status       = d["status"] as? String ?? ""
                let createdBy    = d["createdBy"] as? String ?? ""
                let assignedBy   = d["assignedBy"] as? String ?? ""
                let rate         = Double(d["rate"] as? String ?? "0") ?? 0
                let createdAt    = (d["createdAt"] as? Timestamp)?.dateValue()
                let assignedAt   = (d["assignedAt"] as? Timestamp)?.dateValue()
                let name         = createdBy.isEmpty ? assignedBy : createdBy
                if name.isEmpty { continue }
                if map[name] == nil {
                    map[name] = DispatcherPerformance(
                        id: name, dispatcherName: name,
                        loadsCreated: 0, loadsAssigned: 0,
                        loadsReassigned: 0, avgAssignTimeHours: 0,
                        totalRevenueManagedUSD: 0
                    )
                }
                if !createdBy.isEmpty  { map[name]!.loadsCreated  += 1 }
                if !assignedBy.isEmpty {
                    map[name]!.loadsAssigned += 1
                    map[name]!.totalRevenueManagedUSD += rate
                    if let ca = createdAt, let aa = assignedAt {
                        let hours = aa.timeIntervalSince(ca) / 3600
                        let count = Double(map[name]!.loadsAssigned)
                        let prev  = map[name]!.avgAssignTimeHours
                        map[name]!.avgAssignTimeHours = (prev * (count - 1) + hours) / count
                    }
                }
                if status.lowercased() == "declined" { map[name]!.loadsReassigned += 1 }
            }
            DispatchQueue.main.async {
                dispatchers = Array(map.values)
                dispatchersLoading = false
            }
        }
    }

    
    // MARK: - Fetch Vehicle Performance
    
    func fetchVehiclePerformance() {
        vehiclesLoading = true
        Firestore.firestore().collection("vehicles").getDocuments { vSnap, _ in
            guard let vDocs = vSnap?.documents else {
                DispatchQueue.main.async { vehiclesLoading = false }
                return
            }
            var map: [String: VehiclePerformance] = [:]
            for doc in vDocs {
                let d    = doc.data()
                let unit = d["unitNumber"] as? String ?? ""
                if unit.isEmpty { continue }
                let inspStatus = d["inspectionStatus"] as? String ?? ""
                let passed = (inspStatus == "Passed" || inspStatus == "Cleared") ? 1 : 0
                let failed = (inspStatus == "Failed" || inspStatus == "Needs Repair"
                           || inspStatus == "Accident Reported") ? 1 : 0
                map[unit] = VehiclePerformance(
                    id: doc.documentID,
                    unitNumber: unit,
                    plate: d["plate"] as? String ?? "",
                    tripsCompleted: 0, totalRevenue: 0, maintenanceCount: 0,
                    inspectionsPassed: passed, inspectionsFailed: failed,
                    assignedDriverName: d["assignedDriverName"] as? String ?? "",
                    currentStatus: d["status"] as? String ?? "Active"
                )
            }

            Firestore.firestore().collection("loads")
                .whereField("status", isEqualTo: "Delivered")
                .getDocuments { lSnap, _ in
                    for doc in lSnap?.documents ?? [] {
                        let d    = doc.data()
                        let unit = d["assignedVehicle"] as? String ?? ""
                        let rate = Double(d["rate"] as? String ?? "0") ?? 0
                        if unit.isEmpty { continue }
                        map[unit]?.tripsCompleted += 1
                        map[unit]?.totalRevenue   += rate
                    }

                    Firestore.firestore().collection("maintenance")
                        .getDocuments { mSnap, _ in
                            for doc in mSnap?.documents ?? [] {
                                let unit = doc.data()["vehicleUnit"] as? String ?? ""
                                if unit.isEmpty { continue }
                                map[unit]?.maintenanceCount += 1
                            }

                            Firestore.firestore().collection("reports")
                                .whereField("type", isEqualTo: "inspection")
                                .getDocuments { rSnap, _ in
                                    for doc in rSnap?.documents ?? [] {
                                        let d       = doc.data()
                                        let unit    = d["vehicleNumber"] as? String
                                            ?? d["truckID"] as? String ?? ""
                                        let defects = d["defectsFound"] as? Bool ?? false
                                        if unit.isEmpty { continue }
                                        if defects { map[unit]?.inspectionsFailed += 1 }
                                        else       { map[unit]?.inspectionsPassed += 1 }
                                    }
                                    DispatchQueue.main.async {
                                        vehicles = Array(map.values).filter { !$0.unitNumber.isEmpty }
                                        vehiclesLoading = false
                                    }
                                }
                        }
                }
        }
    }
}


// MARK: - Row Views


struct DriverPerfRow: View {
    let driver: DriverPerformance
    let rank: Int
    var body: some View {
        HStack(spacing: 12) {
            perfRankBadge(rank)
            VStack(alignment: .leading, spacing: 4) {
                Text(driver.driverName).font(.headline)
                HStack(spacing: 12) {
                    Label("\(driver.totalDelivered)", systemImage: "checkmark.seal.fill")
                        .font(.caption).foregroundColor(.green)
                    Label("$\(Int(driver.totalRevenue))", systemImage: "dollarsign.circle.fill")
                        .font(.caption).foregroundColor(.blue)
                    Label(String(format: "%.0f%% on time", driver.onTimeRate),
                          systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(driver.onTimeRate >= 80 ? .green :
                                         driver.onTimeRate >= 60 ? .orange : .red)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray).font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct DispatcherPerfRow: View {
    let dispatcher: DispatcherPerformance
    let rank: Int
    var body: some View {
        HStack(spacing: 12) {
            perfRankBadge(rank)
            VStack(alignment: .leading, spacing: 4) {
                Text(dispatcher.dispatcherName).font(.headline)
                HStack(spacing: 12) {
                    Label("\(dispatcher.loadsCreated) created", systemImage: "plus.circle.fill")
                        .font(.caption).foregroundColor(.blue)
                    Label("\(dispatcher.loadsAssigned) assigned", systemImage: "person.fill.checkmark")
                        .font(.caption).foregroundColor(.purple)
                    Label(String(format: "%.0f%% reassign", dispatcher.reassignRate),
                          systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(dispatcher.reassignRate <= 10 ? .green :
                                         dispatcher.reassignRate <= 25 ? .orange : .red)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray).font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct VehiclePerfRow: View {
    let vehicle: VehiclePerformance
    let rank: Int
    var body: some View {
        HStack(spacing: 12) {
            perfRankBadge(rank)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Unit \(vehicle.unitNumber)").font(.headline)
                    Text(vehicle.currentStatus)
                        .font(.caption2).fontWeight(.semibold)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(vehicleStatusColor(vehicle.currentStatus).opacity(0.15))
                        .foregroundColor(vehicleStatusColor(vehicle.currentStatus))
                        .clipShape(Capsule())
                }
                HStack(spacing: 12) {
                    Label("\(vehicle.tripsCompleted) trips", systemImage: "shippingbox.fill")
                        .font(.caption).foregroundColor(.blue)
                    Label("$\(Int(vehicle.totalRevenue))", systemImage: "dollarsign.circle.fill")
                        .font(.caption).foregroundColor(.green)
                    Label(String(format: "%.0f%% pass", vehicle.inspectionPassRate),
                          systemImage: "checkmark.shield.fill")
                        .font(.caption)
                        .foregroundColor(vehicle.inspectionPassRate >= 80 ? .green :
                                         vehicle.inspectionPassRate >= 60 ? .orange : .red)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(.gray).font(.caption)
        }
        .padding(.vertical, 4)
    }
    func vehicleStatusColor(_ s: String) -> Color {
        switch s {
        case "Active":         return .green
        case "In Maintenance": return .orange
        default:               return .gray
        }
    }
}


// MARK: - Detail Views


struct DriverPerformanceDetailView: View {
    @Environment(\.dismiss) var dismiss
    let driver: DriverPerformance
    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        PerfDetailCard(value: "\(driver.totalDelivered)",
                                       label: "Delivered", icon: "checkmark.seal.fill", color: .green)
                        PerfDetailCard(value: "$\(Int(driver.totalRevenue))",
                                       label: "Revenue", icon: "dollarsign.circle.fill", color: .blue)
                        PerfDetailCard(
                            value: String(format: "%.0f%%", driver.onTimeRate),
                            label: "On-Time", icon: "clock.fill",
                            color: driver.onTimeRate >= 80 ? .green : driver.onTimeRate >= 60 ? .orange : .red)
                        PerfDetailCard(
                            value: String(format: "%.0f%%", driver.declinedRate),
                            label: "Decline Rate", icon: "xmark.circle.fill",
                            color: driver.declinedRate <= 10 ? .green : driver.declinedRate <= 25 ? .orange : .red)
                    }
                    .padding(.vertical, 6)
                }
                Section("Breakdown") {
                    DetailRow(label: "Loads Delivered",    value: "\(driver.totalDelivered)")
                    DetailRow(label: "Loads Declined",     value: "\(driver.totalDeclined)")
                    DetailRow(label: "On Time",            value: "\(driver.onTimeCount)")
                    DetailRow(label: "Late",               value: "\(driver.lateCount)")
                    DetailRow(label: "Avg Revenue / Load", value: "$\(String(format: "%.2f", driver.avgRevenuePerLoad))")
                    DetailRow(label: "Avg Load Duration",  value: formatHours(driver.avgLoadDurationHours))
                }
                Section("Rating") {
                    HStack {
                        Text("Overall").foregroundColor(.secondary)
                        Spacer()
                        Text(driverRating).fontWeight(.bold)
                    }
                }
            }
            .navigationTitle(driver.driverName)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
    var driverRating: String {
        let score = driver.onTimeRate * 0.5 + (100 - driver.declinedRate) * 0.3
            + min(Double(driver.totalDelivered) / 10.0 * 100, 100) * 0.2
        switch score {
        case 90...: return "Excellent ⭐⭐⭐⭐⭐"
        case 75...: return "Good ⭐⭐⭐⭐"
        case 60...: return "Average ⭐⭐⭐"
        case 40...: return "Below Average ⭐⭐"
        default:    return "Needs Improvement ⭐"
        }
    }
}

struct DispatcherPerformanceDetailView: View {
    @Environment(\.dismiss) var dismiss
    let dispatcher: DispatcherPerformance
    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        PerfDetailCard(value: "\(dispatcher.loadsCreated)",
                                       label: "Created", icon: "plus.circle.fill", color: .blue)
                        PerfDetailCard(value: "\(dispatcher.loadsAssigned)",
                                       label: "Assigned", icon: "person.fill.checkmark", color: .purple)
                        PerfDetailCard(value: "$\(Int(dispatcher.totalRevenueManagedUSD))",
                                       label: "Managed", icon: "dollarsign.circle.fill", color: .green)
                        PerfDetailCard(
                            value: String(format: "%.0f%%", dispatcher.reassignRate),
                            label: "Reassign %", icon: "arrow.triangle.2.circlepath",
                            color: dispatcher.reassignRate <= 10 ? .green : dispatcher.reassignRate <= 25 ? .orange : .red)
                    }
                    .padding(.vertical, 6)
                }
                Section("Breakdown") {
                    DetailRow(label: "Loads Created",    value: "\(dispatcher.loadsCreated)")
                    DetailRow(label: "Loads Assigned",   value: "\(dispatcher.loadsAssigned)")
                    DetailRow(label: "Loads Reassigned", value: "\(dispatcher.loadsReassigned)")
                    DetailRow(label: "Avg Assign Time",  value: formatHours(dispatcher.avgAssignTimeHours))
                    DetailRow(label: "Revenue Managed",  value: "$\(String(format: "%.2f", dispatcher.totalRevenueManagedUSD))")
                }
            }
            .navigationTitle(dispatcher.dispatcherName)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}

struct VehiclePerformanceDetailView: View {
    @Environment(\.dismiss) var dismiss
    let vehicle: VehiclePerformance
    var body: some View {
        NavigationStack {
            List {
                Section("Summary") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        PerfDetailCard(value: "\(vehicle.tripsCompleted)",
                                       label: "Trips", icon: "shippingbox.fill", color: .blue)
                        PerfDetailCard(value: "$\(Int(vehicle.totalRevenue))",
                                       label: "Revenue", icon: "dollarsign.circle.fill", color: .green)
                        PerfDetailCard(
                            value: String(format: "%.0f%%", vehicle.inspectionPassRate),
                            label: "Pass Rate", icon: "checkmark.shield.fill",
                            color: vehicle.inspectionPassRate >= 80 ? .green : vehicle.inspectionPassRate >= 60 ? .orange : .red)
                        PerfDetailCard(value: "\(vehicle.maintenanceCount)",
                                       label: "Maintenance", icon: "wrench.fill", color: .orange)
                    }
                    .padding(.vertical, 6)
                }
                Section("Vehicle Info") {
                    DetailRow(label: "Unit Number",     value: vehicle.unitNumber)
                    DetailRow(label: "Plate",           value: vehicle.plate)
                    DetailRow(label: "Status",          value: vehicle.currentStatus)
                    DetailRow(label: "Assigned Driver", value: vehicle.assignedDriverName.isEmpty
                              ? "Unassigned" : vehicle.assignedDriverName)
                }
                Section("Performance") {
                    DetailRow(label: "Trips Completed",     value: "\(vehicle.tripsCompleted)")
                    DetailRow(label: "Total Revenue",       value: "$\(String(format: "%.2f", vehicle.totalRevenue))")
                    DetailRow(label: "Avg Revenue / Trip",  value: "$\(String(format: "%.2f", vehicle.avgRevenuePerTrip))")
                    DetailRow(label: "Maintenance Records", value: "\(vehicle.maintenanceCount)")
                    DetailRow(label: "Inspections Passed",  value: "\(vehicle.inspectionsPassed)")
                    DetailRow(label: "Inspections Failed",  value: "\(vehicle.inspectionsFailed)")
                }
            }
            .navigationTitle("Unit \(vehicle.unitNumber)")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}


// MARK: - Shared UI Components

struct PerfStatCard: View {
    let value: String
    let label: String
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3).fontWeight(.bold).foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
}

struct PerfDetailCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title2).foregroundColor(color)
            Text(value)
                .font(.title3).fontWeight(.bold).foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}

@ViewBuilder
func perfRankBadge(_ rank: Int) -> some View {
    ZStack {
        Circle()
            .fill(rank == 1 ? Color.yellow :
                  rank == 2 ? Color(.systemGray3) :
                  rank == 3 ? Color.orange : Color(.systemGray5))
            .frame(width: 36, height: 36)
        Text(rank <= 3 ? ["🥇","🥈","🥉"][rank-1] : "\(rank)")
            .font(rank <= 3 ? .title3 : .subheadline)
            .fontWeight(.bold)
    }
}

func formatHours(_ hours: Double) -> String {
    if hours == 0 { return "—" }
    let h = Int(hours)
    let m = Int((hours - Double(h)) * 60)
    return m == 0 ? "\(h)h avg" : "\(h)h \(m)m avg"
}

#Preview {
    NavigationStack { PerformanceView() }
        .environmentObject(AppState())
}
