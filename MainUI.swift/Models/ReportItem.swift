import SwiftUI

struct ReportItem: Identifiable {

    var id = UUID()

    var reportNumber: String
    var reportType: String
    var vehicleNumber: String
    var driverName: String
    var date: Date
}


