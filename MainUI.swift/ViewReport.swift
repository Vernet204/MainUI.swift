import SwiftUI
import FirebaseFirestore

struct ViewReport: View {

    @EnvironmentObject private var appState: AppState
    @State private var filterType: String = "All"

    private let filters = ["All", "Repair", "Accident", "Inspection"]

    var body: some View {
        List {

            // FILTER TABS
            Section {
                Picker("Filter", selection: $filterType) {
                    ForEach(filters, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            // REPORT LIST
            Section("Reports") {
                if filteredReports.isEmpty {
                    ContentUnavailableView(
                        "No Reports",
                        systemImage: "doc.text.magnifyingglass"
                    )
                } else {
                    ForEach(filteredReports) { report in
                        VStack(alignment: .leading, spacing: 6) {

                            HStack {
                                Text(report.reportNumber)
                                    .font(.headline)
                                Spacer()
                                Text(report.reportType)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(typeColor(report.reportType).opacity(0.15))
                                    .foregroundColor(typeColor(report.reportType))
                                    .clipShape(Capsule())
                            }

                            Text("Vehicle: \(report.vehicleNumber)")
                                .font(.subheadline)

                            Text("Driver: \(report.driverName)")
                                .font(.subheadline)

                            Text(report.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        let ids = filteredReports.map { $0.id }
                        let toDelete = indexSet.map { ids[$0] }
                        appState.reports.removeAll { toDelete.contains($0.id) }
                    }
                }
            }
        }
        .navigationTitle("View Reports")
        .onAppear { fetchReports() }
    }

    // MARK: - Deduplicated + Filtered Reports
    private var filteredReports: [ReportItem] {
        let sorted = deduplicatedReports.sorted { $0.date > $1.date }

        if filterType == "All" {
            return sorted
        }

        return sorted.filter {
            $0.reportType.lowercased() == filterType.lowercased()
        }
    }

    // MARK: - Deduplication Logic
    private var deduplicatedReports: [ReportItem] {
        var seen = Set<String>()
        var unique: [ReportItem] = []

        for report in appState.reports {

            // ✅ Build a unique key per report type
            let key: String

            switch report.reportType.lowercased() {

            case "inspection":
                // Unique by: driver + vehicle + date (day only)
                let dayString = Calendar.current.startOfDay(for: report.date)
                    .formatted(.iso8601.year().month().day())
                key = "inspection_\(report.driverName.lowercased())_\(report.vehicleNumber.lowercased())_\(dayString)"

            case "repair":
                // Unique by: driver + vehicle + issue type + date (day only)
                let dayString = Calendar.current.startOfDay(for: report.date)
                    .formatted(.iso8601.year().month().day())
                key = "repair_\(report.driverName.lowercased())_\(report.vehicleNumber.lowercased())_\(report.issueType.lowercased())_\(dayString)"

            case "accident":
                // Accidents are unique by driver + vehicle + full timestamp
                // since multiple accidents in a day are possible
                key = "accident_\(report.driverName.lowercased())_\(report.vehicleNumber.lowercased())_\(report.date.timeIntervalSince1970)"

            default:
                // Fallback — unique by report number
                key = report.reportNumber
            }

            // ✅ Only add if we haven't seen this key before
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(report)
            }
        }

        return unique
    }

    // MARK: - Color by type
    private func typeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "repair":      return .orange
        case "accident":    return .red
        case "inspection":  return .green
        default:            return .gray
        }
    }

    // MARK: - Fetch from Firestore
    func fetchReports() {
        Firestore.firestore()
            .collection("reports")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching reports: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                DispatchQueue.main.async {
                    appState.reports = documents.compactMap { doc in
                        let data = doc.data()

                        let rawType = data["type"] as? String ?? ""
                        let reportType = rawType.prefix(1).uppercased() + rawType.dropFirst()

                        return ReportItem(
                            reportNumber: data["reportNumber"] as? String ?? doc.documentID,
                            reportType: reportType,
                            vehicleNumber: data["truckID"] as? String ?? data["vehicleNumber"] as? String ?? "",
                            driverName: data["driverName"] as? String ?? data["driver"] as? String ?? "",
                            date: (data["inspectionDate"] as? Timestamp)?.dateValue()
                                ?? (data["dateReported"] as? Timestamp)?.dateValue()
                                ?? (data["date"] as? Timestamp)?.dateValue()
                                ?? Date(),
                            severity: data["severity"] as? String ?? "—",
                            location: data["location"] as? String ?? "—",
                            issueType: data["issueType"] as? String ?? "—",
                            trailerID: data["trailerID"] as? String ?? "—",
                            status: data["status"] as? String ?? "—",
                            issueDescription: data["issueDescription"] as? String
                                ?? data["defectDescription"] as? String ?? "—",
                            odometer: data["odometer"] as? String ?? "—",
                            defectsFound: data["defectsFound"] as? Bool ?? false
                        )
                    }
                }
            }
    }
}

#Preview {
    NavigationStack {
        ViewReport()
    }
    .environmentObject(AppState())
}
