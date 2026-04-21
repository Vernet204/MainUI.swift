//
//  DriverScheduleView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/12/26.
//


import SwiftUI
import FirebaseFirestore

struct DriverScheduleView: View {

    @State private var schedules: [DriverSchedule] = []
    @State private var isLoading = true
    @State private var selectedWeekOffset = 0
    @State private var selectedDate = Date()
    @State private var filterPickup = Date()
    @State private var filterDelivery = Date().addingTimeInterval(3600 * 8)
    @State private var showFilterSheet = false
    @State private var isFiltering = false
    @State private var selectedDriver: ScheduleDriver? = nil
    @State private var navigateToAssign = false
    @State private var listener: ListenerRegistration? = nil

    // Week days for calendar strip
    var weekDays: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(
            from: calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear],
                from: Calendar.current.date(
                    byAdding: .weekOfYear,
                    value: selectedWeekOffset,
                    to: Date()
                )!
            )
        )!
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: startOfWeek)
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Week Navigation
            VStack(spacing: 8) {
                HStack {
                    Button {
                        selectedWeekOffset -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    Text(weekRangeTitle)
                        .font(.headline)

                    Spacer()

                    Button {
                        selectedWeekOffset += 1
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)

                // Day strip
                HStack(spacing: 0) {
                    ForEach(weekDays, id: \.self) { day in
                        Button {
                            selectedDate = day
                        } label: {
                            VStack(spacing: 4) {
                                Text(dayLetter(day))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(dayNumber(day))
                                    .font(.headline)
                                    .foregroundColor(
                                        isSelected(day) ? .white :
                                        isToday(day) ? .blue : .primary
                                    )
                                    .frame(width: 36, height: 36)
                                    .background(
                                        isSelected(day) ? Color.blue :
                                        isToday(day) ? Color.blue.opacity(0.1) : Color.clear
                                    )
                                    .clipShape(Circle())

                                // ✅ Dot if loads exist on this day
                                Circle()
                                    .fill(loadsExistOn(day) ? Color.orange : Color.clear)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)

                // ✅ Load filter for availability
                Button {
                    showFilterSheet = true
                } label: {
                    HStack {
                        Image(systemName: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundColor(isFiltering ? .orange : .blue)
                        Text(isFiltering
                             ? "Filtered: \(filterPickup.formatted(date: .abbreviated, time: .shortened)) → \(filterDelivery.formatted(date: .abbreviated, time: .shortened))"
                             : "Filter by Load Window")
                            .font(.caption)
                            .foregroundColor(isFiltering ? .orange : .blue)
                        Spacer()
                        if isFiltering {
                            Button("Clear") {
                                isFiltering = false
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                    .background(isFiltering ? Color.orange.opacity(0.1) : Color.blue.opacity(0.05))
                    .cornerRadius(8)
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            // MARK: - Driver Schedules List
            if isLoading {
                Spacer()
                ProgressView("Loading schedules...")
                Spacer()
            } else if filteredSchedules.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Drivers",
                    systemImage: "person.slash",
                    description: Text("Add drivers to see their schedules.")
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredSchedules) { schedule in

                            DriverScheduleCard(
                                schedule: schedule,
                                selectedDate: selectedDate,
                                weekDays: weekDays,
                                isFiltering: isFiltering,
                                filterPickup: filterPickup,
                                filterDelivery: filterDelivery
                            ) {
                                // ✅ Tap to assign
                                selectedDriver = ScheduleDriver(
                                    id: schedule.id,
                                    name: schedule.driverName,
                                    vehicleUnit: schedule.vehicleUnit,
                                    availabilityStatus: schedule.overallStatus,
                                    currentLoads: [],
                                    nextAvailableTime: nil
                                )
                                navigateToAssign = true
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Driver Schedule")
        .navigationDestination(isPresented: $navigateToAssign) {
            if let driver = selectedDriver {
                AssignLoadView(preselectedDriver: driver)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    selectedWeekOffset = 0
                    selectedDate = Date()
                } label: {
                    Text("Today")
                        .font(.caption)
                }
            }
        }
        .onAppear { fetchSchedules() }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
        .refreshable { fetchSchedules() }
        .sheet(isPresented: $showFilterSheet) {
            LoadWindowFilterView(
                pickup: $filterPickup,
                delivery: $filterDelivery,
                isFiltering: $isFiltering
            )
        }
    }

    // MARK: - Filtered Schedules
    var filteredSchedules: [DriverSchedule] {
        guard isFiltering else {
            return schedules.sorted {
                schedulePriority($0.overallStatus) < schedulePriority($1.overallStatus)
            }
        }

        // ✅ When filtering, sort available drivers to top
        return schedules.sorted { a, b in
            let aAvailable = isDriverAvailable(a, pickup: filterPickup, delivery: filterDelivery)
            let bAvailable = isDriverAvailable(b, pickup: filterPickup, delivery: filterDelivery)
            if aAvailable != bAvailable { return aAvailable }
            return schedulePriority(a.overallStatus) < schedulePriority(b.overallStatus)
        }
    }

    func isDriverAvailable(_ schedule: DriverSchedule, pickup: Date, delivery: Date) -> Bool {
        for load in schedule.loads {
            let overlaps = pickup < load.deliveryDateTime && delivery > load.pickupDateTime
            if overlaps { return false }
        }
        return true
    }

    func loadsExistOn(_ day: Date) -> Bool {
        let calendar = Calendar.current
        return schedules.contains { schedule in
            schedule.loads.contains { load in
                calendar.isDate(load.pickupDateTime, inSameDayAs: day) ||
                calendar.isDate(load.deliveryDateTime, inSameDayAs: day)
            }
        }
    }

    // MARK: - Calendar Helpers
    var weekRangeTitle: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }

    func dayLetter(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "E"
        return String(f.string(from: date).prefix(1))
    }

    func dayNumber(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }

    func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }

    func isSelected(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }

    // Update schedulePriority
    func schedulePriority(_ status: String) -> Int {
        switch status {
        case "In Transit": return 0
        case "Accepted":   return 1  // ✅ added
        case "Assigned":   return 2
        case "Available":  return 3
        default:           return 4
        }
    }

    // MARK: - Fetch Schedules
    func fetchSchedules() {
        isLoading = true

        Firestore.firestore()
            .collection("users")
            .whereField("role", isEqualTo: "Driver")
            .getDocuments { snapshot, _ in
                guard let driverDocs = snapshot?.documents else {
                    DispatchQueue.main.async { isLoading = false }
                    return
                }

                let db = Firestore.firestore()
                var fetchedSchedules: [DriverSchedule] = []
                let group = DispatchGroup()

                for driverDoc in driverDocs {
                    let d = driverDoc.data()
                    let name = d["name"] as? String ?? ""
                    let vehicleUnit = d["vehicleUnit"] as? String ?? "Unassigned"

                    group.enter()
                    
                    

                    // In fetchSchedules() — update the whereField to include all active statuses
                    db.collection("loads")
                        .whereField("assignedDriver", isEqualTo: name)
                        .whereField("status", in: ["Assigned", "Accepted", "In Transit"]) // ✅ added Accepted
                        .getDocuments { loadSnapshot, _ in
                            let loadDocs = loadSnapshot?.documents ?? []

                            let scheduledLoads = loadDocs.map { doc -> ScheduledLoad in
                                let ld = doc.data()
                                return ScheduledLoad(
                                    id: doc.documentID,
                                    loadID: ld["loadID"] as? String ?? doc.documentID,
                                    pickupLocation: ld["pickupLocation"] as? String ?? "",
                                    deliveryLocation: ld["deliveryLocation"] as? String ?? "",
                                    pickupDateTime: (ld["pickupDateTime"] as? Timestamp)?.dateValue() ?? Date(),
                                    deliveryDateTime: (ld["deliveryDateTime"] as? Timestamp)?.dateValue() ?? Date(),
                                    status: ld["status"] as? String ?? "",
                                    hasConflict: false
                                )
                            }

                            let hasConflicts = detectConflicts(scheduledLoads)
                            let markedLoads = scheduledLoads.map { load -> ScheduledLoad in
                                var l = load
                                l.hasConflict = hasConflicts
                                return l
                            }

                            // Update overallStatus logic to handle Accepted
                            let overallStatus: String
                            if markedLoads.contains(where: { $0.status == "In Transit" }) {
                                overallStatus = "In Transit"
                            } else if markedLoads.contains(where: { $0.status == "Accepted" }) {
                                overallStatus = "Accepted"   // ✅ added
                            } else if !markedLoads.isEmpty {
                                overallStatus = "Assigned"
                            } else {
                                overallStatus = "Available"
                            }

                            fetchedSchedules.append(DriverSchedule(
                                id: driverDoc.documentID,
                                driverName: name,
                                vehicleUnit: vehicleUnit,
                                loads: markedLoads,
                                overallStatus: overallStatus,
                                hasConflicts: hasConflicts
                            ))

                            group.leave()
                        }
                }

                group.notify(queue: .main) {
                    schedules = fetchedSchedules
                    isLoading = false
                }
            }
    }

    func detectConflicts(_ loads: [ScheduledLoad]) -> Bool {
        for i in 0..<loads.count {
            for j in (i+1)..<loads.count {
                let a = loads[i]
                let b = loads[j]
                if a.pickupDateTime < b.deliveryDateTime && a.deliveryDateTime > b.pickupDateTime {
                    return true
                }
            }
        }
        return false
    }
}

// MARK: - Driver Schedule Card
struct DriverScheduleCard: View {

    let schedule: DriverSchedule
    let selectedDate: Date
    let weekDays: [Date]
    let isFiltering: Bool
    let filterPickup: Date
    let filterDelivery: Date
    var onTap: () -> Void

    var isAvailableForFilter: Bool {
        guard isFiltering else { return true }
        for load in schedule.loads {
            if filterPickup < load.deliveryDateTime && filterDelivery > load.pickupDateTime {
                return false
            }
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // DRIVER HEADER
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(schedule.driverName)
                        .font(.headline)
                    Text("Vehicle: \(schedule.vehicleUnit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // ✅ Availability badge
                if isFiltering {
                    Text(isAvailableForFilter ? "Available" : "Unavailable")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            isAvailableForFilter
                            ? Color.green.opacity(0.15)
                            : Color.red.opacity(0.15)
                        )
                        .foregroundColor(isAvailableForFilter ? .green : .red)
                        .clipShape(Capsule())
                } else {
                    Text(schedule.overallStatus)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusColor(schedule.overallStatus).opacity(0.15))
                        .foregroundColor(statusColor(schedule.overallStatus))
                        .clipShape(Capsule())
                }
            }

            // MARK: - Timeline Bar for the week
            ZStack(alignment: .leading) {

                // Background grid
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { i in
                        Rectangle()
                            .fill(i % 2 == 0
                                  ? Color(.systemGray6)
                                  : Color(.systemGray5))
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                    }
                }
                .cornerRadius(8)

                // ✅ Filter window overlay
                if isFiltering {
                    GeometryReader { geo in
                        let totalWidth = geo.size.width
                        let startX = xPosition(for: filterPickup, totalWidth: totalWidth)
                        let endX = xPosition(for: filterDelivery, totalWidth: totalWidth)
                        let barWidth = max(endX - startX, 4)

                        Rectangle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: barWidth, height: 36)
                            .offset(x: startX)
                    }
                    .frame(height: 36)
                }

                // ✅ Load bars
                if !schedule.loads.isEmpty {
                    GeometryReader { geo in
                        let totalWidth = geo.size.width
                        ForEach(schedule.loads) { load in
                            let startX = xPosition(for: load.pickupDateTime, totalWidth: totalWidth)
                            let endX = xPosition(for: load.deliveryDateTime, totalWidth: totalWidth)
                            let barWidth = max(endX - startX, 8)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(load.hasConflict ? Color.red : loadColor(load.status))
                                .frame(width: barWidth, height: 24)
                                .offset(x: startX, y: 6)
                                .overlay(
                                    Text(load.loadID)
                                        .font(.system(size: 8))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .padding(.horizontal, 2)
                                        .offset(x: startX, y: 6)
                                    , alignment: .leading
                                )
                        }
                    }
                    .frame(height: 36)
                } else {
                    Text("No loads this week")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                }

                // ✅ Today line
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let todayX = xPosition(for: Date(), totalWidth: totalWidth)
                    if todayX >= 0 && todayX <= totalWidth {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 2, height: 36)
                            .offset(x: todayX)
                    }
                }
                .frame(height: 36)
            }
            .frame(height: 36)

            // Day labels under bar
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.self) { day in
                    Text(shortDay(day))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // LOAD DETAILS for selected day
            let dayLoads = loadsOn(selectedDate)
            if !dayLoads.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Loads on \(selectedDate.formatted(date: .abbreviated, time: .omitted)):")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    ForEach(dayLoads) { load in
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(loadColor(load.status))
                                .frame(width: 4, height: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(load.loadID) — \(load.status)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                Text("\(load.pickupLocation) → \(load.deliveryLocation)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }

            // Conflict warning
            if schedule.hasConflicts {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    Text("Scheduling conflict detected")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            // ✅ Assign button
            Button {
                onTap()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(isAvailableForFilter ? "Assign Load to \(schedule.driverName)" : "View Schedule")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isAvailableForFilter ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    schedule.hasConflicts ? Color.red.opacity(0.4) :
                    isFiltering && isAvailableForFilter ? Color.green.opacity(0.4) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }

    // MARK: - Helpers
    func loadsOn(_ date: Date) -> [ScheduledLoad] {
        schedule.loads.filter { load in
            let calendar = Calendar.current
            return calendar.isDate(load.pickupDateTime, inSameDayAs: date) ||
                   calendar.isDate(load.deliveryDateTime, inSameDayAs: date) ||
                   (load.pickupDateTime <= date && load.deliveryDateTime >= date)
        }
    }

    func xPosition(for date: Date, totalWidth: CGFloat) -> CGFloat {
        guard let first = weekDays.first, let last = weekDays.last else { return 0 }
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 1, to: last)!
        let totalSeconds = endOfWeek.timeIntervalSince(first)
        let elapsed = date.timeIntervalSince(first)
        let ratio = CGFloat(elapsed / totalSeconds)
        return min(max(ratio * totalWidth, 0), totalWidth)
    }

    func shortDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "E"
        return String(f.string(from: date).prefix(1))
    }

    // Update statusColor in DriverScheduleCard
    func statusColor(_ status: String) -> Color {
        switch status {
        case "Available":  return .green
        case "Assigned":   return .blue
        case "Accepted":   return .green  // ✅ added
        case "In Transit": return .orange
        default:           return .gray
        }
    }

    func loadColor(_ status: String) -> Color {
        switch status {
        case "Assigned":   return .blue
        case "Accepted":   return .green
        case "In Transit": return .purple
        case "Declined":   return .red
        default:           return .gray
        }
    }}

// MARK: - Load Window Filter Sheet
struct LoadWindowFilterView: View {

    @Environment(\.dismiss) var dismiss
    @Binding var pickup: Date
    @Binding var delivery: Date
    @Binding var isFiltering: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Load Time Window") {
                    DatePicker(
                        "Pickup Date & Time",
                        selection: $pickup,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .onChange(of: pickup) { newValue in
                        if delivery <= newValue {
                            delivery = newValue.addingTimeInterval(3600 * 4)
                        }
                    }

                    DatePicker(
                        "Delivery Date & Time",
                        selection: $delivery,
                        in: pickup...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section {
                    Text("Drivers available during this window will be highlighted green. Drivers with conflicting loads will be marked unavailable.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Filter by Load Window")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        isFiltering = true
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Models
struct DriverSchedule: Identifiable {
    let id: String
    var driverName: String
    var vehicleUnit: String
    var loads: [ScheduledLoad]
    var overallStatus: String
    var hasConflicts: Bool
}

struct ScheduledLoad: Identifiable {
    let id: String
    var loadID: String
    var pickupLocation: String
    var deliveryLocation: String
    var pickupDateTime: Date
    var deliveryDateTime: Date
    var status: String
    var hasConflict: Bool
}






