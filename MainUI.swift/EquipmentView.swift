import SwiftUI

struct EquipmentView: View {

    @State private var equipment: [Equipment] = []

    var body: some View {

        List(equipment) { truck in
            VStack(alignment: .leading) {
                Text(truck.vehicleNumber)
                    .font(.headline)

                Text("Inspection: \(truck.inspectionStatus)")
            }
        }
        .navigationTitle("Fleet Equipment")
    }
}
