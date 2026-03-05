import SwiftUI

struct ClientListView: View {

    @State private var clients: [Client] = []

    var body: some View {

        List(clients) { client in
            VStack(alignment: .leading) {
                Text(client.companyName)
                    .font(.headline)

                Text(client.brokerName)
            }
        }
        .navigationTitle("Clients")
    }
}