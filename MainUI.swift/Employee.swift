import Foundation

// MARK: Employee
struct Employee: Identifiable {
    let id = UUID()
    var name: String
    var role: String
    var hireDate: Date
}

// MARK: Client
struct Client: Identifiable {
    let id = UUID()
    var companyName: String
    var brokerName: String
    var phone: String
    var email: String
}

// MARK: Equipment
struct Equipment: Identifiable {
    let id = UUID()
    var vehicleNumber: String
    var vin: String
    var make: String
    var model: String
    var year: String
    var inspectionStatus: String
}

// MARK: Report
struct Report: Identifiable {
    let id = UUID()
    var reportType: String
    var vehicleNumber: String
    var driverName: String
}