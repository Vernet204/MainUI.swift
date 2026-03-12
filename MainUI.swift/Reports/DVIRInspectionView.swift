import SwiftUI
import FirebaseFirestore

struct DVIRInspectionView: View {
    
    // Driver & Vehicle Info
    @State private var driverName = ""
    @State private var truckID = ""
    @State private var trailerID = ""
    @State private var odometer = ""
    @State private var inspectionDate = Date()
    
    // Safety Checks
    @State private var brakesOK = false
    @State private var tiresOK = false
    @State private var lightsOK = false
    @State private var mirrorsOK = false
    @State private var hornOK = false
    @State private var engineOK = false
    
    // Defects
    @State private var defectsFound = false
    @State private var defectDescription = ""
    
    // Confirmation
    @State private var showConfirmation = false
    
    var body: some View {
        
        Form {
            
            // Driver Info
            Section("Driver Information") {
                TextField("Driver Name", text: $driverName)
                DatePicker("Inspection Date", selection: $inspectionDate, displayedComponents: .date)
            }
            
            // Vehicle Details
            Section("Vehicle Details") {
                TextField("Truck ID", text: $truckID)
                TextField("Trailer ID", text: $trailerID)
                TextField("Odometer Reading", text: $odometer)
                    .keyboardType(.numberPad)
            }
            
            // Safety Checklist
            Section("Safety Inspection Checklist") {
                Toggle("Brakes Operational", isOn: $brakesOK)
                Toggle("Tires in Good Condition", isOn: $tiresOK)
                Toggle("Lights & Signals Working", isOn: $lightsOK)
                Toggle("Mirrors Secure & Functional", isOn: $mirrorsOK)
                Toggle("Horn Working", isOn: $hornOK)
                Toggle("Engine & Fluids OK", isOn: $engineOK)
            }
            
            // Defects
            Section("Defects & Issues") {
                
                Toggle("Defects Found?", isOn: $defectsFound)
                
                if defectsFound {
                    TextField("Describe Defects...", text: $defectDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            
            // Submit Button
            Section {
                
                Button {
                    submitDVIR()
                } label: {
                    
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
    
    
    // MARK: Submit DVIR
    func submitDVIR() {
        
        Firestore.firestore()
            .collection("reports")
            .addDocument(data: [
                
                "type": "inspection",
                "driver": driverName,
                "truckID": truckID,
                "trailerID": trailerID,
                "odometer": odometer,
                "inspectionDate": Timestamp(date: inspectionDate),
                
                "brakesOK": brakesOK,
                "tiresOK": tiresOK,
                "lightsOK": lightsOK,
                "mirrorsOK": mirrorsOK,
                "hornOK": hornOK,
                "engineOK": engineOK,
                
                "defectsFound": defectsFound,
                "defectDescription": defectDescription,
                
                "status": "submitted"
            ]) { error in
                
                if let error = error {
                    print("Error submitting DVIR:", error.localizedDescription)
                    return
                }
                
                print("DVIR Report Logged for Compliance")
                showConfirmation = true
            }
    }
}
