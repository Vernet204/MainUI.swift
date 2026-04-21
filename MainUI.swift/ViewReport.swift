import SwiftUI
import FirebaseFirestore

struct ViewReport: View {

    @EnvironmentObject private var appState: AppState
    @State private var filterType: String = "All"
    @State private var selectedReport: ReportItem? = nil

    var body: some View {
        List {

            // FILTER
            Section {
                Picker("Filter", selection: $filterType) {
                    ForEach(reportTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            // REPORT LIST
            Section("Reports") {
                if filteredReports.isEmpty {
                    ContentUnavailableView(
                        "No reports",
                        systemImage: "doc.text.magnifyingglass"
                    )
                } else {
                    ForEach(filteredReports.sorted(by: { $0.date > $1.date })) { report in

                        // ✅ Tap to open edit sheet
                        Button {
                            selectedReport = report
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {

                                HStack {
                                    Text(report.reportNumber.isEmpty ? "No Number" : report.reportNumber)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(report.reportType)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.thinMaterial)
                                        .clipShape(Capsule())

                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                HStack {
                                    Label(report.vehicleNumber, systemImage: "truck.box")
                                    Spacer()
                                    Label(report.driverName, systemImage: "person.fill")
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                                HStack {
                                    Text(report.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    Spacer()

                                    // ✅ Status badge
                                    if !report.status.isEmpty && report.status != "submitted" {
                                        Text(report.status)
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(statusColor(report.status).opacity(0.15))
                                            .foregroundColor(statusColor(report.status))
                                            .clipShape(Capsule())
                                    }

                                    // ✅ Severity badge if applicable
                                    if !report.severity.isEmpty {
                                        Text(report.severity)
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(severityColor(report.severity).opacity(0.15))
                                            .foregroundColor(severityColor(report.severity))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { indexSet in
                        let ids = filteredReports.sorted(by: { $0.date > $1.date }).enumerated()
                            .filter { indexSet.contains($0.offset) }
                            .map { $0.element.id }
                        appState.reports.removeAll { ids.contains($0.id) }
                    }
                }
            }
        }
        .navigationTitle("Reports")
        .onAppear { fetchReports() }
        // ✅ Edit sheet
        .sheet(item: $selectedReport) { report in
            ReportEditView(report: report)
        }
    }

    // MARK: - Filtered Reports
    private var filteredReports: [ReportItem] {
        if filterType == "All" { return appState.reports }
        return appState.reports.filter { $0.reportType == filterType }
    }

    private var reportTypes: [String] {
        let types = Set(appState.reports.map { $0.reportType })
        return ["All"] + types.sorted()
    }

    func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "open":        return .red
        case "in progress": return .orange
        case "resolved":    return .green
        default:            return .gray
        }
    }

    func severityColor(_ severity: String) -> Color {
        switch severity {
        case "Low":      return .green
        case "Medium":   return .yellow
        case "High":     return .orange
        case "Critical", "Major": return .red
        case "Moderate": return .orange
        default:         return .gray
        }
    }

    // MARK: - Firebase Fetch
    func fetchReports() {
        Firestore.firestore()
            .collection("reports")
            .getDocuments { snapshot, error in
                guard let documents = snapshot?.documents else { return }

                let seen = NSMutableSet()
                var results: [ReportItem] = []

                for doc in documents {
                    let data = doc.data()
                    let type = (data["type"] as? String ?? "").capitalized
                    let driver = data["driverName"] as? String
                        ?? data["driver"] as? String ?? ""
                    let truck = data["truckID"] as? String
                        ?? data["vehicleNumber"] as? String ?? ""
                    let date = (data["inspectionDate"] as? Timestamp)?.dateValue()
                        ?? (data["dateReported"] as? Timestamp)?.dateValue()
                        ?? (data["date"] as? Timestamp)?.dateValue()
                        ?? Date()

                    // Deduplication key
                    let key = "\(type)-\(driver)-\(truck)-\(Calendar.current.startOfDay(for: date))"
                    guard !seen.contains(key) else { continue }
                    seen.add(key)

                    let item = ReportItem(
                        reportNumber: data["reportNumber"] as? String ?? "",
                        reportType: type,
                        vehicleNumber: truck,
                        driverName: driver,
                        date: date,
                        severity: data["severity"] as? String ?? "",
                        location: data["location"] as? String ?? "",
                        issueType: data["issueType"] as? String ?? "",
                        trailerID: data["trailerID"] as? String ?? "",
                        status: data["status"] as? String ?? "Open",
                        issueDescription: data["issueDescription"] as? String
                            ?? data["defectDescription"] as? String ?? "",
                        odometer: data["odometer"] as? String ?? "",
                        defectsFound: data["defectsFound"] as? Bool ?? false
                    )
                    results.append(item)
                }

                DispatchQueue.main.async {
                    appState.reports = results
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
