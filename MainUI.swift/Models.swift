import Foundation

// MARK: - Fleet

struct Vehicle: Identifiable {
    let id = UUID()
    var unitNumber: String
    var vin: String
    var make: String
    var model: String
    var year: String
    var plateNumber: String
    var inspectionStatus: String
    var insuranceStatus: String
}
struct Driver: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var assignedVehicleNumber: String?
    var status: String
    var Email: String
}

// MARK: - Reports


