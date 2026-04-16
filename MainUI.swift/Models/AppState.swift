//
//  AppState.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/18/26.
//

import Foundation
import SwiftUI
import FirebaseFirestore

final class AppState: ObservableObject {
    @Published var loads: [Load] = []
    @Published var reports: [ReportItem] = []

    // ✅ Store listeners so we can remove them later
    private var loadsListener: ListenerRegistration?
    private var reportsListener: ListenerRegistration?

    // MARK: - Start Real-time Loads Listener
    func startListeningToLoads() {
        // Remove existing listener before starting new one
        loadsListener?.remove()

        loadsListener = Firestore.firestore()
            .collection("loads")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Loads listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                DispatchQueue.main.async {
                    self.loads = documents.compactMap { doc in
                        let d = doc.data()
                        return Load(
                            loadID: d["loadID"] as? String ?? doc.documentID,
                            pickup: d["pickupLocation"] as? String ?? "",
                            delivery: d["deliveryLocation"] as? String ?? "",
                            weight: d["weight"] as? String ?? "",
                            rate: d["rate"] as? String ?? "",
                            status: d["status"] as? String ?? "Unassigned"
                        )
                    }
                }
            }
    }

    // MARK: - Start Real-time Reports Listener
    func startListeningToReports() {
        reportsListener?.remove()

        reportsListener = Firestore.firestore()
            .collection("reports")
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("❌ Reports listener error: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else { return }

                DispatchQueue.main.async {
                    self.reports = documents.compactMap { doc in
                        let data = doc.data()
                        let rawType = data["type"] as? String ?? ""
                        let reportType = rawType.prefix(1).uppercased() + rawType.dropFirst()

                        return ReportItem(
                            reportNumber: data["reportNumber"] as? String ?? doc.documentID,
                            reportType: reportType,
                            vehicleNumber: data["truckID"] as? String ?? "",
                            driverName: data["driverName"] as? String ?? data["driver"] as? String ?? "",
                            date: (data["inspectionDate"] as? Timestamp)?.dateValue()
                                ?? (data["dateReported"] as? Timestamp)?.dateValue()
                                ?? Date(),
                            severity: data["severity"] as? String ?? "—",
                            location: data["location"] as? String ?? "—",
                            issueType: data["issueType"] as? String ?? "—",
                            trailerID: data["trailerID"] as? String ?? "—",
                            status: data["status"] as? String ?? "—",
                            issueDescription: data["issueDescription"] as? String ?? "—",
                            odometer: data["odometer"] as? String ?? "—",
                            defectsFound: data["defectsFound"] as? Bool ?? false
                        )
                    }
                }
            }
    }

    // MARK: - Stop All Listeners
    func stopAllListeners() {
        loadsListener?.remove()
        reportsListener?.remove()
        loadsListener = nil
        reportsListener = nil
        print("🔇 All Firestore listeners removed")
    }
}

