//
//  ReportEditView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/19/26.
//


import SwiftUI
import FirebaseFirestore

struct ReportEditView: View {

    @Environment(\.dismiss) var dismiss
    let report: ReportItem

    @State private var status: String = ""
    @State private var resolutionNotes = ""
    @State private var isSaving = false
    @State private var showRestoreVehicle = false
    @State private var vehicleRestored = false

    let statuses = ["Open", "In Progress", "Resolved"]

    var body: some View {
        NavigationStack {
            Form {

                // MARK: - Report Info
                Section("Report Info") {
                    DetailRow(label: "Report #", value: report.reportNumber)
                    DetailRow(label: "Type", value: report.reportType)
                    DetailRow(label: "Driver", value: report.driverName)
                    DetailRow(label: "Vehicle", value: report.vehicleNumber)
                    DetailRow(label: "Date", value: report.date.formatted(date: .abbreviated, time: .shortened))
                    if !report.trailerID.isEmpty {
                        DetailRow(label: "Trailer", value: report.trailerID)
                    }
                }

                // MARK: - Type-specific details
                if !report.issueType.isEmpty {
                    Section("Issue Details") {
                        DetailRow(label: "Issue Type", value: report.issueType)
                        if !report.issueDescription.isEmpty {
                            DetailRow(label: "Description", value: report.issueDescription)
                        }
                        if !report.location.isEmpty {
                            DetailRow(label: "Location", value: report.location)
                        }
                    }
                }

                if report.reportType.lowercased() == "inspection" {
                    Section("Inspection Results") {
                        DetailRow(
                            label: "Defects Found",
                            value: report.defectsFound ? "⚠️ Yes" : "✅ No"
                        )
                        if !report.odometer.isEmpty {
                            DetailRow(label: "Odometer", value: report.odometer)
                        }
                        if !report.issueDescription.isEmpty {
                            DetailRow(label: "Defect Notes", value: report.issueDescription)
                        }
                    }
                }

                if !report.severity.isEmpty {
                    Section("Severity") {
                        HStack {
                            Text("Level")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(report.severity)
                                .fontWeight(.semibold)
                                .foregroundColor(severityColor(report.severity))
                        }
                    }
                }

                // MARK: - Status Update
                Section("Update Status") {
                    Picker("Status", selection: $status) {
                        ForEach(statuses, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: - Resolution Notes
                Section("Resolution Notes") {
                    TextField(
                        "Describe how this was resolved...",
                        text: $resolutionNotes,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }

                // MARK: - Restore Vehicle
                if status == "Resolved" && !report.vehicleNumber.isEmpty && !vehicleRestored {
                    Section {
                        Button {
                            showRestoreVehicle = true
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text("Restore Vehicle to Active")
                                    .foregroundColor(.green)
                                    .fontWeight(.semibold)
                            }
                        }
                    } footer: {
                        Text("This will set \(report.vehicleNumber) back to Active status.")
                            .font(.caption)
                    }
                }

                if vehicleRestored {
                    Section {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("\(report.vehicleNumber) restored to Active")
                                .foregroundColor(.green)
                        }
                    }
                }

                // MARK: - Save
                Section {
                    Button {
                        saveChanges()
                    } label: {
                        if isSaving {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Changes")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle(report.reportNumber)
            .onAppear {
                status = report.status.isEmpty ? "Open" : report.status
                resolutionNotes = ""
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog(
                "Restore \(report.vehicleNumber) to Active?",
                isPresented: $showRestoreVehicle,
                titleVisibility: .visible
            ) {
                Button("Yes, Restore to Active") {
                    restoreVehicle()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will mark the vehicle as Active and clear its maintenance flag.")
            }
        }
    }

    func severityColor(_ severity: String) -> Color {
        switch severity {
        case "Low":      return .green
        case "Medium":   return .yellow
        case "High":     return .orange
        case "Critical": return .red
        case "Major":    return .red
        case "Moderate": return .orange
        case "Minor":    return .green
        default:         return .gray
        }
    }

    func restoreVehicle() {
        // ✅ Find vehicle by unit number and restore to Active
        Firestore.firestore()
            .collection("vehicles")
            .whereField("unitNumber", isEqualTo: report.vehicleNumber)
            .getDocuments { snapshot, _ in
                guard let doc = snapshot?.documents.first else { return }
                doc.reference.updateData([
                    "status": "Active",
                    "inspectionStatus": "Cleared",
                    "clearedAt": Timestamp()
                ])
                DispatchQueue.main.async {
                    vehicleRestored = true
                }
            }
    }

    func saveChanges() {
        isSaving = true

        // ✅ Find the report document and update it
        Firestore.firestore()
            .collection("reports")
            .whereField("reportNumber", isEqualTo: report.reportNumber)
            .getDocuments { snapshot, _ in
                guard let doc = snapshot?.documents.first else {
                    DispatchQueue.main.async { isSaving = false }
                    return
                }

                var updateData: [String: Any] = [
                    "status": status,
                    "updatedAt": Timestamp()
                ]

                if !resolutionNotes.isEmpty {
                    updateData["resolutionNotes"] = resolutionNotes
                }

                doc.reference.updateData(updateData) { _ in
                    DispatchQueue.main.async {
                        isSaving = false
                        dismiss()
                    }
                }
            }
    }
}
