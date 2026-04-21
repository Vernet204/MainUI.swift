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
    @Published var reports: [ReportItem] = []  // ✅ Empty — Firestore is source of truth

    private var reportListener: ListenerRegistration? = nil

    func startListeningToReports() {
        reportListener?.remove()
        reportListener = Firestore.firestore()
            .collection("reports")
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else { return }

                let seen = NSMutableSet()
                var results: [ReportItem] = []

                for doc in docs {
                    let data = doc.data()
                    let type = (data["type"] as? String ?? "").capitalized
                    let driver = data["driverName"] as? String
                        ?? data["driver"] as? String ?? ""
                    let truck = data["truckID"] as? String
                        ?? data["vehicleNumber"] as? String ?? ""
                    let date = (data["inspectionDate"] as? Timestamp)?.dateValue()
                        ?? (data["dateReported"] as? Timestamp)?.dateValue()
                        ?? (data["date"] as? Timestamp)?.dateValue()
                        ?? Date()

                    let key = "\(type)-\(driver)-\(truck)-\(Calendar.current.startOfDay(for: date))"
                    guard !seen.contains(key) else { continue }
                    seen.add(key)

                    results.append(ReportItem(
                        reportNumber: data["reportNumber"] as? String ?? "",
                        reportType: type,
                        vehicleNumber: truck,
                        driverName: driver,
                        date: date,
                        severity: data["severity"] as? String ?? "",
                        location: data["location"] as? String ?? "",
                        issueType: data["issueType"] as? String ?? "",
                        trailerID: data["trailerID"] as? String ?? "",
                        status: data["status"] as? String ?? "Open",
                        issueDescription: data["issueDescription"] as? String
                            ?? data["defectDescription"] as? String ?? "",
                        odometer: data["odometer"] as? String ?? "",
                        defectsFound: data["defectsFound"] as? Bool ?? false
                    ))
                }

                DispatchQueue.main.async {
                    self.reports = results
                }
            }
    }

    func stopAllListeners() {
        reportListener?.remove()
        reportListener = nil
    }
}
