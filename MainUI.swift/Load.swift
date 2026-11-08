//
//  Load.swift
//  MainUI.swift
//
//  Multi-stop load model.
//  Canonical representation is `stops: [Stop]`. Legacy single pickup/delivery
//  accessors are derived from the first pickup and last delivery for display
//  compatibility with existing views.
//

import Foundation
import FirebaseFirestore

// MARK: - Stop

enum StopType: String, Codable, CaseIterable, Identifiable {
    case pickup
    case delivery

    var id: String { rawValue }

    var label: String {
        switch self {
        case .pickup:   return "Pickup"
        case .delivery: return "Delivery"
        }
    }
}

enum StopStatus: String, Codable, CaseIterable {
    case pending      // not yet reached
    case arrived      // driver is at the stop, loading/unloading
    case completed    // left the stop

    var label: String {
        switch self {
        case .pending:   return "Pending"
        case .arrived:   return "Arrived"
        case .completed: return "Completed"
        }
    }
}

struct Stop: Identifiable, Hashable, Codable {
    var id: String = UUID().uuidString
    var type: StopType = .pickup
    var address: String = ""
    var datetime: Date = Date()
    var reference: String = ""   // PO#, BOL#, pickup/drop number, etc.

    //  Per-stop progression — tracked independently of the overall load status.
    var status: StopStatus = .pending
    var arrivedAt: Date? = nil
    var completedAt: Date? = nil

    // MARK: Firestore encoding
    var firestoreDict: [String: Any] {
        var d: [String: Any] = [
            "id":        id,
            "type":      type.rawValue,
            "address":   address,
            "datetime":  Timestamp(date: datetime),
            "reference": reference,
            "status":    status.rawValue
        ]
        if let a = arrivedAt   { d["arrivedAt"]   = Timestamp(date: a) }
        if let c = completedAt { d["completedAt"] = Timestamp(date: c) }
        return d
    }

    init(
        id: String = UUID().uuidString,
        type: StopType = .pickup,
        address: String = "",
        datetime: Date = Date(),
        reference: String = "",
        status: StopStatus = .pending,
        arrivedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.address = address
        self.datetime = datetime
        self.reference = reference
        self.status = status
        self.arrivedAt = arrivedAt
        self.completedAt = completedAt
    }

    init?(firestore raw: Any) {
        guard let d = raw as? [String: Any] else { return nil }
        self.id        = d["id"] as? String ?? UUID().uuidString
        self.type      = StopType(rawValue: (d["type"] as? String ?? "pickup").lowercased()) ?? .pickup
        self.address   = d["address"] as? String ?? ""
        self.datetime  = (d["datetime"] as? Timestamp)?.dateValue() ?? Date()
        self.reference = d["reference"] as? String ?? ""
        self.status    = StopStatus(rawValue: d["status"] as? String ?? "pending") ?? .pending
        self.arrivedAt   = (d["arrivedAt"]   as? Timestamp)?.dateValue()
        self.completedAt = (d["completedAt"] as? Timestamp)?.dateValue()
    }
}

extension Array where Element == Stop {
    /// Decode a stops array from a Firestore field.
    static func fromFirestore(_ raw: Any?) -> [Stop] {
        guard let arr = raw as? [Any] else { return [] }
        return arr.compactMap { Stop(firestore: $0) }
    }

    /// Encode for `addDocument` / `updateData`.
    var firestoreArray: [[String: Any]] {
        map { $0.firestoreDict }
    }

    var firstPickup: Stop? { first(where: { $0.type == .pickup }) }
    var lastDelivery: Stop? { last(where: { $0.type == .delivery }) }

    /// True when every stop has been completed by the driver.
    var allCompleted: Bool {
        !isEmpty && allSatisfy { $0.status == .completed }
    }
}

// MARK: - Firestore write mirror
//
// Writes to the `loads` collection should also mirror the first-pickup and
// last-delivery into the top-level fields so Firestore queries that sort or
// filter by `pickupDateTime`/`deliveryDateTime` keep working.
enum LoadWrite {
    /// Build the stops-related fields that must be included on every load write.
    static func stopFields(_ stops: [Stop]) -> [String: Any] {
        var out: [String: Any] = [
            "stops": stops.firestoreArray
        ]
        if let p = stops.firstPickup {
            out["pickupLocation"] = p.address
            out["pickupDateTime"] = Timestamp(date: p.datetime)
        }
        if let d = stops.lastDelivery {
            out["deliveryLocation"] = d.address
            out["deliveryDateTime"] = Timestamp(date: d.datetime)
        }
        return out
    }
}

// MARK: - Load

struct Load: Identifiable, Codable {
    var id: String = ""

    // ── Core load fields ──────────────────────────────────────
    var loadID: String = ""

    /// Canonical multi-stop representation. First pickup / last delivery are
    /// surfaced as `pickupLocation` / `deliveryLocation` for display.
    var stops: [Stop] = []

    var weight: String = ""
    var rate: String = ""
    var commodity: String = ""
    var specialInstructions: String = ""
    var status: String = "Unassigned"

    // ── Assignment ────────────────────────────────────────────
    var assignedDriver: String = ""
    var assignedDriverID: String = ""
    var assignedVehicle: String = ""
    var assignedBy: String = ""
    var createdBy: String = ""

    // ── Client / Broker ───────────────────────────────────────
    var clientID: String = ""
    var clientName: String = ""
    var clientEmail: String = ""
    var brokerName: String = ""
    var brokerEmail: String = ""
    var brokerAccountingEmail: String = ""
    var brokerPhone: String = ""
    var brokerMC: String = ""
    var brokerDOT: String = ""
    var brokerContactName: String = ""

    // ── Documents ─────────────────────────────────────────────
    var rateConURL: String = ""
    var bolURL: String = ""
    var signedBolURL: String = ""
    var bolSentToBroker: Bool = false
    var bolSentAt: Date? = nil

    // ── Timestamps ────────────────────────────────────────────
    var createdAt: Date? = nil
    var acceptedAt: Date? = nil
    var assignedAt: Date? = nil
    var transitStartedAt: Date? = nil
    var deliveredAt: Date? = nil
    var declinedAt: Date? = nil
    var undeliveredAt: Date? = nil

    // ── Factoring ─────────────────────────────────────────────
    var factoringSubmitted: Bool = false
    var factoringSubmittedAt: Date? = nil

    // MARK: Derived legacy accessors
    var pickupLocation: String   { stops.firstPickup?.address ?? "" }
    var deliveryLocation: String { stops.lastDelivery?.address ?? "" }
    var pickupDateTime: Date     { stops.firstPickup?.datetime ?? Date() }
    var deliveryDateTime: Date   { stops.lastDelivery?.datetime ?? Date() }
    var pickupDate: String       { stops.firstPickup?.datetime.formatted(date: .abbreviated, time: .shortened) ?? "" }
    var dropoffDate: String      { stops.lastDelivery?.datetime.formatted(date: .abbreviated, time: .shortened) ?? "" }

    // MARK: - Init from Firestore document
    init(id: String, data: [String: Any]) {
        self.id = id
        self.loadID              = data["loadID"] as? String ?? ""
        self.stops               = Self.decodeStops(from: data)
        self.weight              = data["weight"] as? String ?? ""
        self.rate                = data["rate"] as? String ?? ""
        self.commodity           = data["commodity"] as? String ?? ""
        self.specialInstructions = data["specialInstructions"] as? String ?? ""
        self.status              = data["status"] as? String ?? "Unassigned"
        self.assignedDriver      = data["assignedDriver"] as? String ?? ""
        self.assignedDriverID    = data["assignedDriverID"] as? String ?? ""
        self.assignedVehicle     = data["assignedVehicle"] as? String ?? ""
        self.assignedBy          = data["assignedBy"] as? String ?? ""
        self.createdBy           = data["createdBy"] as? String ?? ""
        self.clientID            = data["clientID"] as? String ?? ""
        self.clientName          = data["clientName"] as? String ?? ""
        self.clientEmail         = data["clientEmail"] as? String ?? ""
        self.brokerName          = data["brokerName"] as? String ?? ""
        self.brokerEmail         = data["brokerEmail"] as? String ?? ""
        self.brokerAccountingEmail = data["brokerAccountingEmail"] as? String ?? ""
        self.brokerPhone         = data["brokerPhone"] as? String ?? ""
        self.brokerMC            = data["brokerMC"] as? String ?? ""
        self.brokerDOT           = data["brokerDOT"] as? String ?? ""
        self.brokerContactName   = data["brokerContactName"] as? String ?? ""
        self.rateConURL          = data["rateConURL"] as? String ?? ""
        self.bolURL              = data["bolURL"] as? String ?? ""
        self.signedBolURL        = data["signedBolURL"] as? String ?? ""
        self.bolSentToBroker     = data["bolSentToBroker"] as? Bool ?? false
        self.bolSentAt           = (data["bolSentAt"] as? Timestamp)?.dateValue()
        self.createdAt           = (data["createdAt"] as? Timestamp)?.dateValue()
        self.acceptedAt          = (data["acceptedAt"] as? Timestamp)?.dateValue()
        self.assignedAt          = (data["assignedAt"] as? Timestamp)?.dateValue()
        self.transitStartedAt    = (data["transitStartedAt"] as? Timestamp)?.dateValue()
        self.deliveredAt         = (data["deliveredAt"] as? Timestamp)?.dateValue()
        self.declinedAt          = (data["declinedAt"] as? Timestamp)?.dateValue()
        self.undeliveredAt       = (data["undeliveredAt"] as? Timestamp)?.dateValue()
        self.factoringSubmitted  = data["factoringSubmitted"] as? Bool ?? false
        self.factoringSubmittedAt = (data["factoringSubmittedAt"] as? Timestamp)?.dateValue()
    }

    init() {}

    /// Reads the `stops` array if present; otherwise synthesizes a 2-stop
    /// pickup+delivery pair from the legacy top-level fields so pre-redesign
    /// docs continue to render correctly.
    static func decodeStops(from data: [String: Any]) -> [Stop] {
        let decoded = [Stop].fromFirestore(data["stops"])
        if !decoded.isEmpty { return decoded }

        let pickupAddr   = data["pickupLocation"] as? String ?? ""
        let deliveryAddr = data["deliveryLocation"] as? String ?? ""
        let pickupTS     = (data["pickupDateTime"] as? Timestamp)?.dateValue() ?? Date()
        let deliveryTS   = (data["deliveryDateTime"] as? Timestamp)?.dateValue() ?? Date()

        var stops: [Stop] = []
        if !pickupAddr.isEmpty {
            stops.append(Stop(type: .pickup, address: pickupAddr, datetime: pickupTS))
        }
        if !deliveryAddr.isEmpty {
            stops.append(Stop(type: .delivery, address: deliveryAddr, datetime: deliveryTS))
        }
        return stops
    }
}

// MARK: - Lightweight view model used by the Dispatcher Load Board
struct LoadInfo: Identifiable {
    var id: String
    var loadID: String
    var stops: [Stop]
    var status: String
    var commodity: String
    var rate: String
    var weight: String
    var assignedDriver: String

    // Derived legacy fields — kept so existing display code works.
    var pickupLocation: String   { stops.firstPickup?.address ?? "" }
    var deliveryLocation: String { stops.lastDelivery?.address ?? "" }
    var pickupDateTime: Date     { stops.firstPickup?.datetime ?? Date() }
    var deliveryDateTime: Date   { stops.lastDelivery?.datetime ?? Date() }

    /// Build from a Firestore load doc, honoring new stops array with legacy fallback.
    static func from(docID: String, data: [String: Any]) -> LoadInfo {
        LoadInfo(
            id: docID,
            loadID: data["loadID"] as? String ?? docID,
            stops: Load.decodeStops(from: data),
            status: data["status"] as? String ?? "Unassigned",
            commodity: data["commodity"] as? String ?? "",
            rate: data["rate"] as? String ?? "",
            weight: data["weight"] as? String ?? "",
            assignedDriver: data["assignedDriver"] as? String ?? ""
        )
    }
}
