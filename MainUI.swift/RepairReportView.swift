//
//  RepairReportView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/16/26.
//


import SwiftUI

struct RepairReportView: View {
    
    // Driver & Vehicle Info
    @State private var driverName = ""
    @State private var truckID = ""
    @State private var trailerID = ""
    
    // Issue Details (Core to Use Case 3)
    @State private var issueType = "Mechanical"
    @State private var severity = "Medium"
    @State private var issueDescription = ""
    @State private var location = ""
    
    // Submission State
    @State private var reportSubmitted = false
    
    let issueTypes = ["Mechanical", "Tire Issue", "Engine Problem", "Trailer Damage", "Electrical", "Other"]
    let severityLevels = ["Low", "Medium", "High", "Critical"]
    
    var body: some View {
        Form {
            
            // MARK: - Driver Information
            Section(header: Text("Driver Information")) {
                TextField("Driver Name", text: $driverName)
            }
            
            // MARK: - Vehicle Information
            Section(header: Text("Vehicle Information")) {
                TextField("Truck ID", text: $truckID)
                TextField("Trailer ID", text: $trailerID)
            }
            
            // MARK: - Repair Issue Details (Core Use Case)
            Section(header: Text("Repair Issue Details")) {
                
                Picker("Issue Type", selection: $issueType) {
                    ForEach(issueTypes, id: \.self) { type in
                        Text(type)
                    }
                }
                
                Picker("Severity Level", selection: $severity) {
                    ForEach(severityLevels, id: \.self) { level in
                        Text(level)
                    }
                }
                
                TextField("Current Location", text: $location)
                
                TextField("Describe the Issue...", text: $issueDescription, axis: .vertical)
                    .lineLimit(3...6)
            }
            
            // MARK: - Submit Button (Use Case 3 Submission)
            Section {
                Button(action: submitRepairReport) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                        Text("Submit Repair Report")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .navigationTitle("Repair Report")
        .alert("Repair Report Submitted", isPresented: $reportSubmitted) {
            Button("OK", role: .cancel) {}
        }
    }
    
    func submitRepairReport() {
        // Future: Send to Firebase / Fleet Database
        print("Repair Report Logged:")
        print("Driver: \(driverName)")
        print("Truck: \(truckID)")
        print("Issue: \(issueType)")
        print("Severity: \(severity)")
        print("Description: \(issueDescription)")
        
        reportSubmitted = true
    }
}

#Preview {
    RepairReportView()
        .environmentObject(AppState())
}

