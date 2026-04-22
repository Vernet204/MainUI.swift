
import Foundation
 
// MARK: - Employee
struct Employee: Identifiable {
    let id = UUID()
    var name: String
    var role: String
    var hireDate: Date
    var Email: String
}
