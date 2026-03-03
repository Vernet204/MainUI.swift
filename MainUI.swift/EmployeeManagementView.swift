
import SwiftUI

struct EmployeeManagementView: View {

    @State private var employees: [Employee] = []

    var body: some View {

        VStack {

            List(employees) { employee in
                VStack(alignment: .leading) {
                    Text(employee.name)
                        .font(.headline)

                    Text(employee.role)
                        .foregroundColor(.gray)
                }
            }

            NavigationLink("Create New Employee") {
                CreateEmployeeView(employees: $employees)
            }
            .buttonStyle(.borderedProminent)
        }
        .navigationTitle("Employees")
    }
}