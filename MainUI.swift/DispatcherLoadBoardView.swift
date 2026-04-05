//
//  DispatcherLoadBoardView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 4/4/26.
//


import SwiftUI
import FirebaseFirestore

struct DispatcherLoadBoardView: View {

    @State private var loads: [LoadInfo] = []
    @State private var showCreateLoad = false

    var body: some View {
        List {

            ForEach(loads) { load in
                VStack(alignment: .leading, spacing: 6) {

                    HStack {
                        Text("Load ID: \(load.loadID)")
                            .font(.headline)
                        Spacer()
                        Text(load.status)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor(load.status).opacity(0.15))
                            .foregroundColor(statusColor(load.status))
                            .clipShape(Capsule())
                    }

                    Divider()

                    Group {
                        Label("Pickup: \(load.pickupLocation)", systemImage: "mappin.circle")
                        Label("Date & Time: \(load.pickupDate)", systemImage: "clock")
                        Label("Dropoff: \(load.deliveryLocation)", systemImage: "mappin.and.ellipse")
                        Label("Date & Time: \(load.dropoffDate)", systemImage: "clock.fill")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
            }
            .onDelete { indexSet in
                let ids = indexSet.map { loads[$0].id }
                loads.remove(atOffsets: indexSet)
                ids.forEach { id in
                    Firestore.firestore().collection("loads").document(id).delete()
                }
            }
        }
        .navigationTitle("Load Board")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showCreateLoad = true
                } label: {
                    Label("Add Load", systemImage: "plus")
                }
            }
        }
        .onAppear { fetchLoads() }
        .sheet(isPresented: $showCreateLoad, onDismiss: fetchLoads) {
            CreateLoadView()
                .environmentObject(AppState())
        }
    }

    func statusColor(_ status: String) -> Color {
        switch status {
        case "Unassigned": return .orange
        case "Assigned": return .blue
        case "In Transit": return .purple
        case "Delivered": return .green
        default: return .gray
        }
    }

    func fetchLoads() {
        Firestore.firestore().collection("loads")
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents else { return }
                loads = docs.map { doc in
                    let d = doc.data()
                    return LoadInfo(
                        id: doc.documentID,
                        loadID: d["loadID"] as? String ?? doc.documentID,
                        pickupLocation: d["pickupLocation"] as? String ?? "",
                        deliveryLocation: d["deliveryLocation"] as? String ?? "",
                        pickupDate: d["pickupDate"] as? String ?? "TBD",
                        dropoffDate: d["dropoffDate"] as? String ?? "TBD",
                        status: d["status"] as? String ?? "Unassigned"
                    )
                }
            }
    }
}
