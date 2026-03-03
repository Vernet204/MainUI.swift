import SwiftUI

struct ReportItem: Identifiable {
    let id = UUID()
    var title: String
    var date: Date
    var detail: String
}

struct ViewReportsView: View {
    @State private var reports: [ReportItem] = [
        .init(title: "Weekly Revenue", date: .now, detail: "Revenue: $12,450"),
        .init(title: "Fleet Utilization", date: .now, detail: "Utilization: 78%")
    ]

    var body: some View {
        List {
            ForEach(reports) { r in
                VStack(alignment: .leading, spacing: 6) {
                    Text(r.title).font(.headline)
                    Text(r.date.formatted(date: .abbreviated, time: .omitted))
                        .foregroundStyle(.secondary)
                    Text(r.detail)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Reports")
    }
}