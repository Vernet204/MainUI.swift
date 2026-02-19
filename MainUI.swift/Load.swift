//
//  Load.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/16/26.
//


import SwiftUI

import Foundation

struct Load: Identifiable {
    let id = UUID()
    var loadID: String
    var pickup: String
    var delivery: String
    var weight: String
    var rate: String
    var status: String
}

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
                        LoadRowView(load: load)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Load Board")
    }
}

struct LoadRowView: View {
    let load: Load

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            HStack {
                Text(load.loadID)
                    .font(.headline)

                Spacer()

                StatusBadge(status: load.status)
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

struct StatusBadge: View {
    let status: String

    var body: some View {
        Text(status)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }

    private var color: Color {
        switch status {
        case "Unassigned": return .orange
        case "Assigned": return .blue
        case "In Transit": return .purple
        case "Delivered": return .green
        default: return .gray
        }
    }
}

#Preview {
    NavigationStack {
        LoadBoardView()
    }
    .environmentObject(AppState())
}


