import SwiftUI

struct LoadBoardView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack {
            if appState.loads.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)

                    Text("No Loads Yet")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Create a load and it will appear here.")
                        .foregroundColor(.gray)
                }
                .padding()
            } else {
                List {
                    ForEach(appState.loads) { load in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(load.loadID)
                                    .font(.headline)
                                Spacer()
                                Text(load.status)
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }

                            Text("\(load.pickup) → \(load.delivery)")
                                .font(.subheadline)

                            HStack {
                                Text("Weight: \(load.weight)")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("Rate: \(load.rate)")
                                    .foregroundColor(.green)
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Load Board")
    }
}

#Preview {
    NavigationStack {
        LoadBoardView()
    }
    .environmentObject(AppState())
}