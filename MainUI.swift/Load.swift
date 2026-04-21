//
//  Load.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/16/26.
//


import SwiftUI
import Foundation

// MARK: - Load (local model for AppState)
struct Load: Identifiable {
    let id = UUID()
    var loadID: String
    var pickup: String
    var delivery: String
    var weight: String
    var rate: String
    var status: String
}

// MARK: - LoadInfo (Firestore model with proper Date types)
struct LoadInfo: Identifiable {
    let id: String
    var loadID: String
    var pickupLocation: String
    var deliveryLocation: String
    var pickupDateTime: Date
    var deliveryDateTime: Date
    var status: String
    var commodity: String
    var rate: String
    var weight: String
    var assignedDriver: String = ""  // ✅ add this
}

// MARK: - StatusBadge
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
        case "Assigned":   return .blue
        case "Accepted":   return .green
        case "Declined":   return .red
        case "In Transit": return .purple
        case "Delivered":  return .green
        default:           return .gray
        }
    }
}
