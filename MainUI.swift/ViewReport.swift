import SwiftUI
import FirebaseFirestore

/// Owner: View reports (inspection / accident / repair, etc.)
struct ViewReport: View {

    @EnvironmentObject private var appState: AppState
    @State private var filterType: String = "All"

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

                        VStack(alignment: .leading, spacing: 6) {

                            HStack {

                                Text(report.reportNumber)
                                    .font(.headline)

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

                            Text("Driver: \(report.driverName)")
                                .font(.subheadline)

                            Text(report.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        let ids = filteredReports.map { $0.id }
                        let toDelete = indexSet.map { ids[$0] }

                        appState.reports.removeAll { report in
                            toDelete.contains(report.id)
                        }
                    }
                }
            }
        }
        .navigationTitle("View Reports")

        // LOAD FIREBASE DATA
        .onAppear {
            fetchReports()
        }
    }

    // MARK: - FILTERED REPORTS
    private var filteredReports: [ReportItem] {

        if filterType == "All" {
            return appState.reports
        }

        return appState.reports.filter {
            $0.reportType == filterType
        }
    }

    // MARK: - REPORT TYPES
    private var reportTypes: [String] {

        let types = Set(appState.reports.map { $0.reportType })

        return ["All"] + types.sorted()
    }

    // MARK: - FIREBASE FETCH
    func fetchReports() {

        Firestore.firestore()
            .collection("reports")
            .getDocuments { snapshot, error in

                if let error = error {
                    print("Error loading reports:", error.localizedDescription)
                    return
                }

                guard let documents = snapshot?.documents else { return }

                appState.reports = documents.compactMap { doc in

                    let data = doc.data()

                    return ReportItem(
                        reportNumber: data["reportNumber"] as? String ?? "",
                        reportType: data["reportType"] as? String ?? "",
                        vehicleNumber: data["vehicleNumber"] as? String ?? "",
                        driverName: data["driverName"] as? String ?? "",
                        date: (data["date"] as? Timestamp)?.dateValue() ?? Date()
                    )
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
