import SwiftUI
import FirebaseFirestore

struct ViewReport: View {

    @EnvironmentObject private var appState: AppState
    @State private var filterType: String = "All"
    @State private var selectedReport: ReportItem? = nil

    private let filters = ["All", "Repair", "Accident"]

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
                    ContentUnavailableView("No Reports", systemImage: "doc.text.magnifyingglass")
                } else {
                    ForEach(filteredReports.sorted(by: { $0.date > $1.date })) { report in
                        Button {
                            selectedReport = report
                        } label: {
                            // BEFORE CLICK — summary row
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(report.reportNumber)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text(report.reportType)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.thinMaterial)
                                        .clipShape(Capsule())
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
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    // Swipe to delete
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
        // AFTER CLICK — detail sheet
        .sheet(item: $selectedReport) { report in
            ReportDetailView(report: report)
        }
    }

    private var filteredReports: [ReportItem] {
        filterType == "All" ? appState.reports :
        appState.reports.filter { $0.reportType == filterType }
    }

    func fetchReports() {
        Firestore.firestore().collection("reports").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            appState.reports = documents.compactMap { doc in
                let data = doc.data()
                return ReportItem(
                    reportNumber: data["reportNumber"] as? String ?? doc.documentID,
                    reportType: data["type"] as? String ?? "",
                    vehicleNumber: data["truckID"] as? String ?? "",
                    driverName: data["driverName"] as? String ?? data["driver"] as? String ?? "",
                    date: (data["date"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
        }
    }
}

// MARK: - Report Detail View (after click)
struct ReportDetailView: View {

    @Environment(\.dismiss) var dismiss
    let report: ReportItem

    var body: some View {
        NavigationStack {
            List {
                Section("Report Info") {
                    DetailRow(label: "Report #", value: report.reportNumber)
                    DetailRow(label: "Type", value: report.reportType)
                    DetailRow(label: "Date & Time", value: report.date.formatted(date: .long, time: .shortened))
                }

                Section("Vehicle & Driver") {
                    DetailRow(label: "Vehicle (Unit #)", value: report.vehicleNumber)
                    DetailRow(label: "Driver Name", value: report.driverName)
                }

                if report.reportType == "Repair" {
                    Section("Repair Details") {
                        DetailRow(label: "Status", value: "Open")
                        DetailRow(label: "Severity", value: "—")
                        DetailRow(label: "Location", value: "—")
                        DetailRow(label: "Issue Type", value: "—")
                        DetailRow(label: "Trailer ID", value: "—")
                        DetailRow(label: "Issue Description", value: "—")
                    }
                }

                if report.reportType == "Accident" {
                    Section("Accident Details") {
                        DetailRow(label: "Severity", value: "—")
                        DetailRow(label: "Location", value: "—")
                        DetailRow(label: "Trailer ID", value: "—")
                        DetailRow(label: "Issue Description", value: "—")
                    }
                }
            }
            .navigationTitle(report.reportType + " Report")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label).foregroundColor(.gray)
            Spacer()
            Text(value).fontWeight(.medium)
        }
    }
}
#Preview {
    NavigationStack {
        ViewReport()
    }
    .environmentObject(AppState())
}
