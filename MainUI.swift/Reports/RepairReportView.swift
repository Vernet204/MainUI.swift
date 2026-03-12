//
//  RepairReportView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/16/26.
//


import SwiftUI
import FirebaseFirestore

struct RepairReportView: View {
    
    // Driver & Vehicle Info
    @State private var driverName = ""
    @State private var truckID = ""
    @State private var trailerID = ""
    
    // Issue Details
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
            
            // Driver Information
            Section("Driver Information") {
                TextField("Driver Name", text: $driverName)
            }
            
            // Vehicle Information
            Section("Vehicle Information") {
                TextField("Truck ID", text: $truckID)
                TextField("Trailer ID", text: $trailerID)
            }
            
            // Repair Issue Details
            Section("Repair Issue Details") {
                
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
            
            // Submit Button
            Section {
                
                Button {
                    submitRepairReport()
                } label: {
                    
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
    
    
    // MARK: Save to Firebase
    func submitRepairReport() {
        
        Firestore.firestore()
            .collection("reports")
            .addDocument(data: [
                
                "type": "repair",
                "driverName": driverName,
                "truckID": truckID,
                "trailerID": trailerID,
                "issueType": issueType,
                "severity": severity,
                "issueDescription": issueDescription,
                "location": location,
                "dateReported": Timestamp(),
                "status": "open"
                
            ]) { error in
                
                if let error = error {
                    print("Error saving repair report:", error.localizedDescription)
                    return
                }
                
                print("Repair Report saved successfully")
                reportSubmitted = true
            }
    }
}

#Preview {
    NavigationStack {
        RepairReportView()
    }
    .environmentObject(AppState())
}
