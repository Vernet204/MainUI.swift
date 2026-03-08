//
//  AppState.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/18/26.
//


import Foundation
import SwiftUI

final class AppState: ObservableObject {
    @Published var loads: [Load] = []
    @Published var reports: [ReportItem] = [
        ReportItem(
            reportNumber: "REP-001",
            reportType: "Inspection",
            vehicleNumber: "Truck 12",
            driverName: "John Smith",
            date: Date()
        ),
        ReportItem(
            reportNumber: "REP-002",
            reportType: "Accident",
            vehicleNumber: "Truck 5",
            driverName: "Mike Davis",
            date: Date()
        )
    ]
}


