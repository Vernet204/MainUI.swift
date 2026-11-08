//
//  BOLPendingTask.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 6/4/26.
//


//
//  LoadPacketService.swift
//  MainUI.swift
//
//  Handles two dispatcher workflows:
//
//  1. FACTORING PACKET — dispatcher uploads their completed TBS factoring sheet,
//     app combines it with rate con + signed BOL for each selected load
//     into one PDF packet for emailing.
//
//  2. BOL TASK — when a driver uploads a signed BOL, a task appears
//     in the dispatcher dashboard. Dispatcher emails it to the broker
//     invoicing email with the load # as the subject line.
//

import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import MessageUI
import PDFKit
import UIKit
import UniformTypeIdentifiers

// MARK: — BOL Pending Task model
struct BOLPendingTask: Identifiable {
    let id: String          // load document ID
    var loadID: String
    var driverName: String
    var brokerName: String
    var brokerEmail: String
    var brokerAccountingEmail: String
    var signedBolURL: String
    var deliveredAt: Date?
}

// MARK: — Load for packet selection
struct PacketLoad: Identifiable {
    let id: String          // Firestore document ID
    var loadID: String
    var brokerName: String
    var rateConURL: String
    var signedBolURL: String
    var status: String
    var isSelected: Bool = false
}

// MARK: — Load Packet Service
class LoadPacketService: ObservableObject {
    static let shared = LoadPacketService()

    @Published var bolTasks:     [BOLPendingTask] = []
    @Published var packetLoads:  [PacketLoad]     = []
    @Published var isLoading = false

    private let db = Firestore.firestore()

    // ✅ Fetch loads with signed BOL that haven't been emailed to broker yet
    func fetchBOLTasks() {
        db.collection("loads")
            .whereField("bolSentToBroker", isEqualTo: false)
            .whereField("status", isEqualTo: "Delivered")
            .getDocuments { snap, _ in
                guard let docs = snap?.documents else { return }
                let tasks: [BOLPendingTask] = docs.compactMap { doc in
                    let d = doc.data()
                    guard let bolURL = d["signedBolURL"] as? String,
                          !bolURL.isEmpty else { return nil }
                    return BOLPendingTask(
                        id:                   doc.documentID,
                        loadID:               d["loadID"]               as? String ?? "",
                        driverName:           d["assignedDriver"]        as? String ?? "",
                        brokerName:           d["brokerName"]            as? String ?? d["clientName"] as? String ?? "",
                        brokerEmail:          d["brokerEmail"]           as? String ?? "",
                        brokerAccountingEmail: d["brokerAccountingEmail"] as? String ?? "",
                        signedBolURL:         bolURL,
                        deliveredAt:          (d["deliveredAt"] as? Timestamp)?.dateValue()
                    )
                }.sorted { ($0.deliveredAt ?? Date()) > ($1.deliveredAt ?? Date()) }

                DispatchQueue.main.async { self.bolTasks = tasks }
            }
    }

    // ✅ Fetch delivered loads with both rate con and signed BOL for packet building
    func fetchPacketLoads() {
        isLoading = true
        db.collection("loads")
            .whereField("status", isEqualTo: "Delivered")
            .getDocuments { snap, _ in
                guard let docs = snap?.documents else {
                    DispatchQueue.main.async { self.isLoading = false }
                    return
                }
                let loads: [PacketLoad] = docs.compactMap { doc in
                    let d = doc.data()
                    let rateCon   = d["rateConURL"]   as? String ?? ""
                    let signedBol = d["signedBolURL"] as? String ?? ""
                    // Only include loads that have at least a signed BOL
                    guard !signedBol.isEmpty else { return nil }
                    return PacketLoad(
                        id:           doc.documentID,
                        loadID:       d["loadID"]     as? String ?? "",
                        brokerName:   d["brokerName"] as? String ?? d["clientName"] as? String ?? "",
                        rateConURL:   rateCon,
                        signedBolURL: signedBol,
                        status:       d["status"]     as? String ?? ""
                    )
                }.sorted { $0.loadID < $1.loadID }

                DispatchQueue.main.async {
                    self.packetLoads = loads
                    self.isLoading = false
                }
            }
    }

    // ✅ Mark BOL as sent to broker
    func markBOLSent(loadID: String, taskID: String) {
        db.collection("loads").document(taskID).updateData([
            "bolSentToBroker": true,
            "bolSentAt": Timestamp()
        ])
        DispatchQueue.main.async {
            self.bolTasks.removeAll { $0.id == taskID }
        }
    }

    // MARK: — Combine PDFs into one packet
    // Downloads each URL, converts images to PDF pages, merges all into one Data
    func buildPacket(
        factoringSheetData: Data?,
        loads: [PacketLoad],
        completion: @escaping (Data?) -> Void
    ) {
        let group = DispatchGroup()
        var pdfDatas: [Int: Data] = [:]  // keyed by index to preserve order

        // First doc = factoring sheet if provided
        var startIndex = 0
        if let fData = factoringSheetData {
            pdfDatas[0] = fData
            startIndex = 1
        }

        // For each load, download rate con + signed BOL
        for (i, load) in loads.enumerated() {
            let baseIndex = startIndex + (i * 2)

            // Rate con
            if !load.rateConURL.isEmpty {
                group.enter()
                downloadData(from: load.rateConURL) { data in
                    if let data = data { pdfDatas[baseIndex] = data }
                    group.leave()
                }
            }

            // Signed BOL
            if !load.signedBolURL.isEmpty {
                group.enter()
                downloadData(from: load.signedBolURL) { data in
                    if let data = data { pdfDatas[baseIndex + 1] = data }
                    group.leave()
                }
            }
        }

        group.notify(queue: .global()) {
            // Merge all in order
            let sorted = pdfDatas.sorted { $0.key < $1.key }.map { $0.value }
            let merged = self.mergePDFs(datas: sorted)
            DispatchQueue.main.async { completion(merged) }
        }
    }

    // MARK: — Download data from URL
    private func downloadData(from urlString: String, completion: @escaping (Data?) -> Void) {
        guard let url = URL(string: urlString) else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            completion(data)
        }.resume()
    }

    // MARK: — Merge multiple PDFs / images into one PDF Data
    func mergePDFs(datas: [Data]) -> Data {
        let pageW: CGFloat = 612
        let pageH: CGFloat = 792

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH)
        )

        return renderer.pdfData { ctx in
            for data in datas {
                // Try as PDF first
                if let pdfDoc = PDFDocument(data: data) {
                    for pageIndex in 0..<pdfDoc.pageCount {
                        guard let page = pdfDoc.page(at: pageIndex) else { continue }
                        ctx.beginPage()
                        let bounds = page.bounds(for: .mediaBox)
                        let scaleX = pageW / bounds.width
                        let scaleY = pageH / bounds.height
                        let scale  = min(scaleX, scaleY)
                        let cgCtx  = UIGraphicsGetCurrentContext()!
                        cgCtx.scaleBy(x: scale, y: scale)
                        page.draw(with: .mediaBox, to: cgCtx)
                    }
                } else if let image = UIImage(data: data) {
                    // Image (signed BOL photo) — render as PDF page
                    ctx.beginPage()
                    let imgRatio  = image.size.width / image.size.height
                    let pageRatio = pageW / pageH
                    let drawW: CGFloat
                    let drawH: CGFloat
                    if imgRatio > pageRatio {
                        drawW = pageW
                        drawH = pageW / imgRatio
                    } else {
                        drawH = pageH
                        drawW = pageH * imgRatio
                    }
                    let x = (pageW - drawW) / 2
                    let y = (pageH - drawH) / 2
                    image.draw(in: CGRect(x: x, y: y, width: drawW, height: drawH))
                }
            }
        }
    }
}

// MARK: — Factoring Packet View (Dispatcher)
struct FactoringPacketView: View {

    @EnvironmentObject var authManager: AuthManager
    @StateObject private var service  = LoadPacketService.shared
    @StateObject private var compSvc  = CompanyInfoService.shared
    @Environment(\.dismiss) var dismiss

    // Factoring sheet upload
    @State private var showFactoringFilePicker = false
    @State private var factoringSheetData: Data? = nil
    @State private var factoringFileName = ""

    // Load selection
    @State private var selectAll = false

    // Packet
    @State private var isBuildingPacket = false
    @State private var packetData: Data? = nil
    @State private var showMail = false
    @State private var statusMessage = ""

    var selectedLoads: [PacketLoad] {
        service.packetLoads.filter { $0.isSelected }
    }

    var body: some View {
        NavigationStack {
            List {

                // ── Step 1: Upload factoring sheet ────────────────
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Step 1 — Upload Factoring Sheet", systemImage: "1.circle.fill")
                            .font(.headline).foregroundColor(.blue)
                        Text("Upload the completed TBS factoring sheet PDF.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    if factoringSheetData == nil {
                        Button {
                            showFactoringFilePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.badge.plus")
                                Text("Upload Factoring Sheet PDF").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                        }
                    } else {
                        HStack {
                            Image(systemName: "doc.fill").foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(factoringFileName.isEmpty ? "Factoring Sheet" : factoringFileName)
                                    .font(.subheadline).fontWeight(.semibold)
                                Text("✅ Uploaded").font(.caption).foregroundColor(.green)
                            }
                            Spacer()
                            Button {
                                factoringSheetData = nil
                                factoringFileName = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                // ── Step 2: Select loads ──────────────────────────
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Step 2 — Select Loads to Include", systemImage: "2.circle.fill")
                            .font(.headline).foregroundColor(.blue)
                        Text("Select one or more delivered loads. Rate con and signed BOL will be included for each.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    if service.isLoading {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if service.packetLoads.isEmpty {
                        Text("No delivered loads with signed BOL found.")
                            .font(.subheadline).foregroundColor(.secondary)
                    } else {
                        // Select all toggle
                        HStack {
                            Image(systemName: selectAll ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectAll ? .blue : .gray)
                            Text("Select All").fontWeight(.medium)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectAll.toggle()
                            for i in service.packetLoads.indices {
                                service.packetLoads[i].isSelected = selectAll
                            }
                        }

                        ForEach(service.packetLoads.indices, id: \.self) { i in
                            HStack(spacing: 12) {
                                Image(systemName: service.packetLoads[i].isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(service.packetLoads[i].isSelected ? .blue : .gray)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Load \(service.packetLoads[i].loadID)")
                                        .font(.subheadline).fontWeight(.semibold)
                                    Text(service.packetLoads[i].brokerName)
                                        .font(.caption).foregroundColor(.secondary)
                                    HStack(spacing: 8) {
                                        Label(service.packetLoads[i].rateConURL.isEmpty ? "No Rate Con" : "Rate Con ✓",
                                              systemImage: "doc.fill")
                                            .font(.caption2)
                                            .foregroundColor(service.packetLoads[i].rateConURL.isEmpty ? .red : .green)
                                        Label("Signed BOL ✓", systemImage: "signature")
                                            .font(.caption2).foregroundColor(.green)
                                    }
                                }
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                service.packetLoads[i].isSelected.toggle()
                                selectAll = service.packetLoads.allSatisfy { $0.isSelected }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // ── Step 3: Build & email packet ──────────────────
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Step 3 — Build & Email Packet", systemImage: "3.circle.fill")
                            .font(.headline).foregroundColor(.blue)
                        if !selectedLoads.isEmpty {
                            Text("Packet will include: factoring sheet + \(selectedLoads.count) load(s) × (rate con + signed BOL)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    if !statusMessage.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text(statusMessage).foregroundColor(.green).font(.subheadline)
                        }
                    }

                    Button {
                        buildAndSend()
                    } label: {
                        if isBuildingPacket {
                            HStack {
                                ProgressView()
                                Text("Building packet...").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.gray).foregroundColor(.white).cornerRadius(12)
                        } else {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text("Build & Email Packet").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(canBuild ? Color.green : Color.gray)
                            .foregroundColor(.white).cornerRadius(12)
                        }
                    }
                    .disabled(!canBuild || isBuildingPacket)
                }
            }
            .navigationTitle("Factoring Packet")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                service.fetchPacketLoads()
                compSvc.fetch()
            }
            .fileImporter(
                isPresented: $showFactoringFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFactoringImport(result: result)
            }
            .sheet(isPresented: $showMail) {
                if let data = packetData, MFMailComposeViewController.canSendMail() {
                    PacketMailView(
                        packetData: data,
                        companyEmail: compSvc.info.email,
                        loadIDs: selectedLoads.map { $0.loadID }
                    ) { sent in
                        if sent { statusMessage = "✅ Packet sent successfully" }
                    }
                }
            }
        }
    }

    var canBuild: Bool {
        factoringSheetData != nil && !selectedLoads.isEmpty
    }

    func handleFactoringImport(result: Result<[URL], Error>) {
        guard case .success(let urls) = result,
              let url = urls.first,
              url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        if let data = try? Data(contentsOf: url) {
            factoringSheetData = data
            factoringFileName  = url.lastPathComponent
        }
    }

    func buildAndSend() {
        isBuildingPacket = true
        LoadPacketService.shared.buildPacket(
            factoringSheetData: factoringSheetData,
            loads: selectedLoads
        ) { combined in
            DispatchQueue.main.async {
                isBuildingPacket = false
                packetData = combined
                showMail = true
            }
        }
    }
}

// MARK: — Packet Mail View
struct PacketMailView: UIViewControllerRepresentable {
    let packetData:   Data
    let companyEmail: String
    let loadIDs:      [String]
    var onDismiss:    (Bool) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        // Pre-fill from company email if available
        vc.setSubject("Factoring Packet — Load(s): \(loadIDs.joined(separator: ", "))")
        vc.setMessageBody(
            "Please find the attached factoring packet.\n\nLoads included: \(loadIDs.joined(separator: ", "))\n\nThank you,\nGood Partners Express LLC",
            isHTML: false
        )
        let df = DateFormatter(); df.dateFormat = "MMM_d_yyyy"
        vc.addAttachmentData(
            packetData,
            mimeType: "application/pdf",
            fileName: "FactoringPacket_\(df.string(from: Date())).pdf"
        )
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDismiss: (Bool) -> Void
        init(onDismiss: @escaping (Bool) -> Void) { self.onDismiss = onDismiss }
        func mailComposeController(_ c: MFMailComposeViewController,
                                   didFinishWith r: MFMailComposeResult, error: Error?) {
            c.dismiss(animated: true); onDismiss(r == .sent)
        }
    }
}

// MARK: — BOL Task Row (used in Dispatcher Dashboard)
struct BOLTaskRow: View {
    let task: BOLPendingTask
    var onSend: () -> Void

    @State private var showMail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Signed BOL — Load \(task.loadID)")
                        .font(.subheadline).fontWeight(.semibold)
                    Text(task.brokerName.isEmpty ? "Unknown broker" : task.brokerName)
                        .font(.caption).foregroundColor(.secondary)
                    Text("Driver: \(task.driverName)")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    showMail = true
                } label: {
                    Label("Send", systemImage: "envelope.fill")
                        .font(.caption).fontWeight(.semibold)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                }
            }

            if !task.brokerEmail.isEmpty {
                Text("To: \(task.brokerEmail)").font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.06))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.2), lineWidth: 1))
        .sheet(isPresented: $showMail) {
            if MFMailComposeViewController.canSendMail() {
                BOLMailView(task: task) { sent in
                    if sent { onSend() }
                }
            }
        }
    }
}

// MARK: — BOL Mail View (dispatcher sends signed BOL to broker)
struct BOLMailView: UIViewControllerRepresentable {
    let task: BOLPendingTask
    var onDismiss: (Bool) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator

        // Recipients: broker invoicing email
        var recipients: [String] = []
        if !task.brokerAccountingEmail.isEmpty {
            recipients.append(task.brokerAccountingEmail)
        } else if !task.brokerEmail.isEmpty {
            recipients.append(task.brokerEmail)
        }
        vc.setToRecipients(recipients)
        vc.setSubject("Load # \(task.loadID)")
        vc.setMessageBody(
            "Please find the signed Bill of Lading attached for Load \(task.loadID).\n\nThank you,\nGood Partners Express LLC",
            isHTML: false
        )

        // Download and attach signed BOL
        if let url = URL(string: task.signedBolURL),
           let data = try? Data(contentsOf: url) {
            let isPDF = task.signedBolURL.lowercased().contains(".pdf")
            vc.addAttachmentData(
                data,
                mimeType: isPDF ? "application/pdf" : "image/jpeg",
                fileName: isPDF ? "SignedBOL_\(task.loadID).pdf" : "SignedBOL_\(task.loadID).jpg"
            )
        }
        return vc
    }

    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(task: task, onDismiss: onDismiss) }

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let task: BOLPendingTask
        let onDismiss: (Bool) -> Void
        init(task: BOLPendingTask, onDismiss: @escaping (Bool) -> Void) {
            self.task = task; self.onDismiss = onDismiss
        }
        func mailComposeController(_ c: MFMailComposeViewController,
                                   didFinishWith r: MFMailComposeResult, error: Error?) {
            c.dismiss(animated: true)
            if r == .sent {
                // Mark as sent in Firestore
                LoadPacketService.shared.markBOLSent(
                    loadID: task.loadID, taskID: task.id
                )
            }
            onDismiss(r == .sent)
        }
    }
}