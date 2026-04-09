import SwiftUI

struct ReportItem: Identifiable {
    var id = UUID()
    var reportNumber: String
    var reportType: String
    var vehicleNumber: String
    var driverName: String
    var date: Date

    // ✅ Extra detail fields
    var severity: String = "—"
    var location: String = "—"
    var issueType: String = "—"
    var trailerID: String = "—"
    var status: String = "—"
    var issueDescription: String = "—"
    var odometer: String = "—"
    var defectsFound: Bool = false
}

