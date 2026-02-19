//
//  DVIRInspectionView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/16/26.
//


import SwiftUI

struct DVIRInspectionView: View {
    
    // Driver & Vehicle Info (Compliance Required)
    @State private var driverName = ""
    @State private var truckID = ""
    @State private var trailerID = ""
    @State private var odometer = ""
    @State private var inspectionDate = Date()
    
    // Critical Safety Checks (DOT Relevant)
    @State private var brakesOK = false
    @State private var tiresOK = false
    @State private var lightsOK = false
    @State private var mirrorsOK = false
    @State private var hornOK = false
    @State private var engineOK = false
    
    // Defect Reporting (Legally Important)
    @State private var defectsFound = false
    @State private var defectDescription = ""
    
    // Submission State
    @State private var showConfirmation = false
    
    var body: some View {
        Form {
            
            // MARK: - Driver Information
            Section(header: Text("Driver Information")) {
                TextField("Driver Name", text: $driverName)
                DatePicker("Inspection Date", selection: $inspectionDate, displayedComponents: .date)
            }
            
            // MARK: - Vehicle Details
            Section(header: Text("Vehicle Details")) {
                TextField("Truck ID", text: $truckID)
                TextField("Trailer ID", text: $trailerID)
                TextField("Odometer Reading", text: $odometer)
                    .keyboardType(.numberPad)
            }
            
            // MARK: - Safety Inspection Checklist
            Section(header: Text("Safety Inspection Checklist")) {
                Toggle("Brakes Operational", isOn: $brakesOK)
                Toggle("Tires in Good Condition", isOn: $tiresOK)
                Toggle("Lights & Signals Working", isOn: $lightsOK)
                Toggle("Mirrors Secure & Functional", isOn: $mirrorsOK)
                Toggle("Horn Working", isOn: $hornOK)
                Toggle("Engine & Fluids OK", isOn: $engineOK)
            }
            
            // MARK: - Defects Section (Real Fleet Requirement)
            Section(header: Text("Defects & Issues")) {
                Toggle("Defects Found?", isOn: $defectsFound)
                
                if defectsFound {
                    TextField("Describe Defects...", text: $defectDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            
            // MARK: - Submit Report (Compliance Logging)
            Section {
                Button(action: submitDVIR) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Submit DVIR Report")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
        }
        .navigationTitle("DVIR Inspection")
        .alert("DVIR Submitted Successfully", isPresented: $showConfirmation) {
            Button("OK", role: .cancel) {}
        }
    }
    
    func submitDVIR() {
        // Future: Save to Firebase / Database
        print("DVIR Report Logged for Compliance")
        showConfirmation = true
    }

}
