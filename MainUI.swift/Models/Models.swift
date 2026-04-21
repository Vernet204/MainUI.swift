import Foundation

struct Vehicle: Identifiable, Hashable {
    let id = UUID()
    var unitNumber: String
    var plate: String
    var status: String
    var assignedDriverID: String = ""    // ✅ add this
    var assignedDriverName: String = ""  // ✅ add this
}

// MARK: - Report Form Helpers
struct ReportDriver: Identifiable, Hashable {
    let id: String
    var name: String
}

struct ReportVehicle: Identifiable, Hashable {
    let id: String
    var unitNumber: String
    var plate: String
}

// Add to Models.swift
struct DriverOption: Identifiable {
    let id: String
    let name: String
}

struct Driver: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var email: String
    var status: String
}

// MARK: - Reports


