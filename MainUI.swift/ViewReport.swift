import SwiftUI

/// Owner: View reports (inspection / accident / repair, etc.)
/// Renamed from `ViewReportView` -> `ViewReport`.
struct ViewReport: View {
    @EnvironmentObject private var appState: AppState

    @State private var filterType: String = "All"

    private var filteredReports: [ReportItem] {
        if filterType == "All" { return appState.reports }
        return appState.reports.filter { $0.reportType == filterType }
    }

    private var reportTypes: [String] {
        let types = Set(appState.reports.map { $0.reportType })
        return ["All"] + types.sorted()
    }

    var body: some View {
        List {
            Section {
                Picker("Filter", selection: $filterType) {
                    ForEach(reportTypes, id: \.self) { t in
                        Text(t).tag(t)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Reports") {
                if filteredReports.isEmpty {
                    ContentUnavailableView("No reports", systemImage: "doc.text.magnifyingglass")
                } else {
                    ForEach(filteredReports.sorted(by: { $0.date > $1.date })) { r in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(r.reportNumber).font(.headline)
                                Spacer()
                                Text(r.reportType)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.thinMaterial)
                                    .clipShape(Capsule())
                            }
                            Text("Vehicle: \(r.vehicleNumber)").font(.subheadline)
                            Text("Driver: \(r.driverName)").font(.subheadline)
                            Text(r.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { idx in
                        let ids = filteredReports.map { $0.id }
                        let toDelete = idx.map { ids[$0] }
                        appState.reports.removeAll { toDelete.contains($0.id) }
                    }
                }
            }
        }
        .navigationTitle("View Reports")
    }
}

#Preview {
    NavigationStack {
        ViewReport()
    }
    .environmentObject(AppState())
}
