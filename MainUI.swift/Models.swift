import Foundation

// MARK: - Fleet

struct Vehicle: Identifiable, Hashable {
    let id = UUID()
    var number: String
    var vin: String
    var make: String
    var model: String
    var year: String
    var inspectionStatus: String
    var insuranceStatus: String
}

struct Driver: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var assignedVehicleNumber: String?
    var status: String
}

// MARK: - Reports

struct ReportItem: Identifiable, Hashable {
    let id = UUID()
    var reportNumber: String
    var reportType: String
    var vehicleNumber: String
    var driverName: String
    var date: Date
}
