import Foundation

struct Vehicle: Identifiable, Hashable {
    let id = UUID()
    var unitNumber: String
    var plate: String
    var status: String
}

struct Driver: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var email: String
    var status: String
}

// MARK: - Reports


