//
//  ReportDetailView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/8/26.
//
import SwiftUI
import FirebaseFirestore

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

                if report.reportType.lowercased() == "repair" {
                    Section("Repair Details") {
                        DetailRow(label: "Status", value: "Open")
                        DetailRow(label: "Severity", value: "—")
                        DetailRow(label: "Location", value: "—")
                        DetailRow(label: "Issue Type", value: "—")
                        DetailRow(label: "Trailer ID", value: "—")
                        DetailRow(label: "Issue Description", value: "—")
                    }
                }

                if report.reportType.lowercased() == "accident" {
                    Section("Accident Details") {
                        DetailRow(label: "Severity", value: "—")
                        DetailRow(label: "Location", value: "—")
                        DetailRow(label: "Trailer ID", value: "—")
                        DetailRow(label: "Issue Description", value: "—")
                    }
                }

                if report.reportType.lowercased() == "inspection" {
                    Section("Inspection Details") {
                        DetailRow(label: "Truck ID", value: "—")
                        DetailRow(label: "Trailer ID", value: "—")
                        DetailRow(label: "Odometer", value: "—")
                        DetailRow(label: "Defects Found", value: "—")
                        DetailRow(label: "Defect Description", value: "—")
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

#Preview {
    NavigationStack {
        ViewReport()
    }
    .environmentObject(AppState())
}
