import SwiftUI
import FirebaseFirestore

struct ViewReport: View {

    @EnvironmentObject private var appState: AppState
    @State private var filterType: String = "All"
    @State private var expandedReportID: UUID? = nil  // ✅ tracks which row is expanded

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

                        // ✅ Tap to expand/collapse
                        Button {
                            withAnimation {
                                if expandedReportID == report.id {
                                    expandedReportID = nil  // collapse if already open
                                } else {
                                    expandedReportID = report.id  // expand this one
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {

                                // SUMMARY ROW — always visible
                                HStack {
                                    Text(report.reportNumber)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(report.reportType)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(typeColor(report.reportType).opacity(0.15))
                                        .foregroundColor(typeColor(report.reportType))
                                        .clipShape(Capsule())

                                    // Chevron indicator
                                    Image(systemName: expandedReportID == report.id
                                          ? "chevron.up" : "chevron.down")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                Text("Vehicle: \(report.vehicleNumber)")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)

                                Text("Driver: \(report.driverName)")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)

                                Text(report.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                // EXPANDED DETAIL — only shows when tapped
                                if expandedReportID == report.id {
                                    Divider()
                                        .padding(.vertical, 4)

                                    // Common fields
                                    Group {
                                        DetailRow(label: "Report #", value: report.reportNumber)
                                        DetailRow(label: "Type", value: report.reportType)
                                        DetailRow(
                                            label: "Date & Time",
                                            value: report.date.formatted(date: .long, time: .shortened)
                                        )
                                        DetailRow(label: "Vehicle Unit #", value: report.vehicleNumber)
                                        DetailRow(label: "Driver Name", value: report.driverName)
                                    }

                                    // Repair-specific fields
                                    if report.reportType.lowercased() == "repair" {
                                        Divider()
                                            .padding(.vertical, 4)
                                        Text("Repair Details")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)

                                        DetailRow(label: "Severity", value: report.severity)
                                        DetailRow(label: "Location", value: report.location)
                                        DetailRow(label: "Issue Type", value: report.issueType)
                                        DetailRow(label: "Trailer ID", value: report.trailerID)
                                        DetailRow(label: "Status", value: report.status)
                                        DetailRow(label: "Issue Description", value: report.issueDescription)
                                    }

                                    // Accident-specific fields
                                    if report.reportType.lowercased() == "accident" {
                                        Divider()
                                            .padding(.vertical, 4)
                                        Text("Accident Details")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.red)

                                        DetailRow(label: "Severity", value: report.severity)
                                        DetailRow(label: "Location", value: report.location)
                                        DetailRow(label: "Trailer ID", value: report.trailerID)
                                        DetailRow(label: "Issue Description", value: report.issueDescription)
                                    }

                                    // Inspection-specific fields
                                    if report.reportType.lowercased() == "inspection" {
                                        Divider()
                                            .padding(.vertical, 4)
                                        Text("Inspection Details")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.green)

                                        DetailRow(label: "Truck ID", value: report.vehicleNumber)
                                        DetailRow(label: "Trailer ID", value: report.trailerID)
                                        DetailRow(label: "Odometer", value: report.odometer)
                                        DetailRow(label: "Defects Found", value: report.defectsFound ? "Yes" : "No")
                                        DetailRow(label: "Defect Description", value: report.issueDescription)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
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

    // MARK: - Filter Logic
    private var filteredReports: [ReportItem] {
        let sorted = appState.reports.sorted { $0.date > $1.date }
        if filterType == "All" { return sorted }
        return sorted.filter {
            $0.reportType.lowercased() == filterType.lowercased()
        }
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
                            issueDescription: data["issueDescription"] as? String ?? data["defectDescription"] as? String ?? "—",
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

