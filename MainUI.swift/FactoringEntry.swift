//
//  FactoringSheetService.swift
//  MainUI.swift
//
//  Dispatcher uploads their factoring sheet PDF.
//  App merges it with the rate con and signed BOL for each load into one PDF.
//  Dispatcher emails the merged PDF from the company email.
//

import Foundation
import FirebaseFirestore
import FirebaseStorage
import MessageUI
import UIKit
import SwiftUI
import PDFKit
import UniformTypeIdentifiers

// MARK: — Load entry for factoring
struct FactoringEntry: Identifiable {
    let id: String          // Firestore load document ID
    var customer:      String
    var loadNumber:    String
    var originalRate:  String
    var stops:         [Stop]
    var rateConURL:    String
    var signedBolURL:  String
    var createdAt: Date?

    var pickupLocation: String   { stops.firstPickup?.address ?? "" }
    var deliveryLocation: String { stops.lastDelivery?.address ?? "" }
}

// MARK: — Factoring Sheet Service
class FactoringSheetService: ObservableObject {
    static let shared = FactoringSheetService()
    @Published var pendingEntries: [FactoringEntry] = []
    @Published var isLoading = false
    private let db = Firestore.firestore()

    // ✅ Fetch loads that have both a rate con and signed BOL, not yet factored
    func fetchPendingLoads() {
        isLoading = true
        db.collection("loads")
            .whereField("factoringSubmitted", isEqualTo: false)
            .getDocuments { snap, _ in
                guard let docs = snap?.documents else {
                    DispatchQueue.main.async { self.isLoading = false }
                    return
                }
                let entries: [FactoringEntry] = docs.compactMap { doc in
                    let d = doc.data()
                    let rateConURL   = d["rateConURL"]   as? String ?? ""
                    let signedBolURL = d["signedBolURL"] as? String ?? ""
                    // Must have at least a rate con
                    guard !rateConURL.isEmpty else { return nil }
                    let customer = d["brokerName"] as? String ?? d["clientName"] as? String ?? ""
                    let loadNum  = d["loadID"]     as? String ?? ""
                    guard !loadNum.isEmpty else { return nil }
                    return FactoringEntry(
                        id: doc.documentID,
                        customer:         customer,
                        loadNumber:       loadNum,
                        originalRate:     d["rate"] as? String ?? "0",
                        stops:            Load.decodeStops(from: d),
                        rateConURL:       rateConURL,
                        signedBolURL:     signedBolURL,
                        createdAt:        (d["createdAt"] as? Timestamp)?.dateValue()
                    )
                }.sorted { ($0.createdAt ?? Date()) < ($1.createdAt ?? Date()) }
                DispatchQueue.main.async {
                    self.pendingEntries = entries
                    self.isLoading = false
                }
            }
    }

    func markLoadsAsSubmitted(entries: [FactoringEntry]) {
        for e in entries {
            db.collection("loads").document(e.id).updateData([
                "factoringSubmitted":   true,
                "factoringSubmittedAt": Timestamp()
            ])
        }
        DispatchQueue.main.async { self.pendingEntries.removeAll() }
    }

    // MARK: — Merge dispatcher's factoring sheet + rate con + signed BOL into one PDF
    func mergePDFs(
        factoringSheetData: Data,
        entries: [FactoringEntry],
        completion: @escaping (Data?) -> Void
    ) {
        let merged = PDFDocument()

        // 1. Add dispatcher's factoring sheet pages first
        if let factoringDoc = PDFDocument(data: factoringSheetData) {
            for i in 0..<factoringDoc.pageCount {
                if let page = factoringDoc.page(at: i) {
                    merged.insert(page, at: merged.pageCount)
                }
            }
        }

        // 2. For each load, fetch and append rate con + signed BOL
        let group = DispatchGroup()

        for entry in entries {
            // Rate Con
            if !entry.rateConURL.isEmpty, let url = URL(string: entry.rateConURL) {
                group.enter()
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data, let doc = PDFDocument(data: data) {
                        for i in 0..<doc.pageCount {
                            if let page = doc.page(at: i) {
                                DispatchQueue.main.async {
                                    merged.insert(page, at: merged.pageCount)
                                }
                            }
                        }
                    }
                    group.leave()
                }.resume()
            }

            // Signed BOL (image — convert to PDF page)
            if !entry.signedBolURL.isEmpty, let url = URL(string: entry.signedBolURL) {
                group.enter()
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    if let data = data {
                        // Try as PDF first
                        if let doc = PDFDocument(data: data) {
                            for i in 0..<doc.pageCount {
                                if let page = doc.page(at: i) {
                                    DispatchQueue.main.async { merged.insert(page, at: merged.pageCount) }
                                }
                            }
                        }
                        // If it's an image, convert to a PDF page
                        else if let image = UIImage(data: data) {
                            let imgPageData = Self.imageToPDFData(image: image)
                            if let imgDoc = PDFDocument(data: imgPageData), let page = imgDoc.page(at: 0) {
                                DispatchQueue.main.async { merged.insert(page, at: merged.pageCount) }
                            }
                        }
                    }
                    group.leave()
                }.resume()
            }
        }

        group.notify(queue: .main) {
            let finalData = merged.dataRepresentation()
            completion(finalData)
        }
    }

    // Convert UIImage to a single-page PDF
    static func imageToPDFData(image: UIImage) -> Data {
        let pageW: CGFloat = 612; let pageH: CGFloat = 792
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageW, height: pageH))
        return renderer.pdfData { ctx in
            ctx.beginPage()
            let aspect = image.size.width / image.size.height
            let drawW = aspect > 1 ? pageW - 40 : (pageH - 40) * aspect
            let drawH = aspect > 1 ? drawW / aspect : pageH - 40
            let x = (pageW - drawW) / 2; let y = (pageH - drawH) / 2
            image.draw(in: CGRect(x: x, y: y, width: drawW, height: drawH))
        }
    }
}

// MARK: — Factoring Sheet View (Dispatcher)
struct FactoringSheetView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var service  = FactoringSheetService.shared
    @StateObject private var compSvc  = CompanyInfoService.shared

    @State private var selectedEntry: FactoringEntry? = nil
    @State private var status      = ""
    @Environment(\.dismiss) var dismiss

    var total: String {
        String(format: "$%.2f", service.pendingEntries.reduce(0.0) {
            $0 + (Double($1.originalRate) ?? 0)
        })
    }

    var body: some View {
        NavigationStack {
            List {
                if service.isLoading {
                    Section {
                        HStack { Spacer(); VStack(spacing: 8) { ProgressView(); Text("Loading...").font(.caption).foregroundColor(.secondary) }; Spacer() }.padding()
                    }
                } else {

                    // ── Pending loads — tap one to factor it ──────────
                    Section("Pending Loads — Tap to Factor") {
                        if service.pendingEntries.isEmpty {
                            ContentUnavailableView("No Pending Loads", systemImage: "doc.text",
                                description: Text("Loads appear here once rate cons are uploaded."))
                        } else {
                            if !status.isEmpty {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                    Text(status).foregroundColor(.green)
                                }
                            }
                            ForEach(service.pendingEntries) { entry in
                                Button { selectedEntry = entry } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack {
                                                Text(entry.loadNumber).font(.headline).foregroundColor(.primary)
                                                Spacer()
                                                Text("$\(entry.originalRate)").fontWeight(.semibold).foregroundColor(.green)
                                            }
                                            Text(entry.customer).font(.subheadline).foregroundColor(.secondary)
                                            HStack(spacing: 12) {
                                                Label(entry.rateConURL.isEmpty ? "No Rate Con" : "Rate Con ✓",
                                                      systemImage: "doc.fill")
                                                    .font(.caption)
                                                    .foregroundColor(entry.rateConURL.isEmpty ? .red : .green)
                                                Label(entry.signedBolURL.isEmpty ? "No Signed BOL" : "Signed BOL ✓",
                                                      systemImage: "signature")
                                                    .font(.caption)
                                                    .foregroundColor(entry.signedBolURL.isEmpty ? .orange : .green)
                                            }
                                        }
                                        Image(systemName: "chevron.right").foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                            .onDelete { service.pendingEntries.remove(atOffsets: $0) }
                        }
                    }
                }
            }
            .navigationTitle("Factoring Sheet")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { service.fetchPendingLoads(); compSvc.fetch() }
            .sheet(item: $selectedEntry) { entry in
                FactorSingleLoadView(
                    entry: entry,
                    companyInfo: compSvc.info
                ) {
                    status = "✅ Load #\(entry.loadNumber) factored"
                    service.fetchPendingLoads()
                }
            }
        }
    }
}

// MARK: — Factor a Single Load (upload sheet → merge → review → send)
struct FactorSingleLoadView: View {
    let entry: FactoringEntry
    let companyInfo: CompanyInfo
    var onSubmitted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showFilePicker = false
    @State private var sheetData: Data? = nil
    @State private var sheetName = ""
    @State private var isMerging = false
    @State private var mergedPDF: Data? = nil
    @State private var showReview = false

    var body: some View {
        NavigationStack {
            List {
                Section("Load") {
                    DetailRow(label: "Load #",   value: entry.loadNumber)
                    DetailRow(label: "Customer", value: entry.customer)
                    DetailRow(label: "Rate",     value: "$\(entry.originalRate)")
                    if !entry.pickupLocation.isEmpty {
                        DetailRow(label: "Route", value: "\(entry.pickupLocation) → \(entry.deliveryLocation)")
                    }
                    Label(entry.rateConURL.isEmpty ? "No Rate Con on file" : "Rate Con on file ✓",
                          systemImage: "doc.fill")
                        .font(.caption)
                        .foregroundColor(entry.rateConURL.isEmpty ? .red : .green)
                    Label(entry.signedBolURL.isEmpty ? "No Signed BOL on file" : "Signed BOL on file ✓",
                          systemImage: "signature")
                        .font(.caption)
                        .foregroundColor(entry.signedBolURL.isEmpty ? .orange : .green)
                }

                Section("Step 1 — Upload Factoring Sheet") {
                    if sheetData == nil {
                        Button { showFilePicker = true } label: {
                            HStack {
                                Image(systemName: "doc.fill.badge.plus").foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Upload Factoring Sheet PDF").fontWeight(.semibold)
                                    Text("Your completed TBS sheet for this load").font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading).padding()
                            .background(Color.blue.opacity(0.06)).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6])))
                        }
                    } else {
                        HStack {
                            Image(systemName: "doc.fill").foregroundColor(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sheetName.isEmpty ? "Factoring Sheet" : sheetName).fontWeight(.semibold)
                                Text("✅ Ready to merge").font(.caption).foregroundColor(.green)
                            }
                            Spacer()
                            Button { sheetData = nil; sheetName = ""; mergedPDF = nil } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                            }
                        }
                        .padding().background(Color.blue.opacity(0.06)).cornerRadius(10)
                    }
                }

                if sheetData != nil {
                    Section("Step 2 — Merge & Send") {
                        Text("Merged PDF will contain: your factoring sheet + rate con + signed BOL for this load.")
                            .font(.caption).foregroundColor(.secondary)
                        Button { mergeAndPrepare() } label: {
                            if isMerging {
                                ProgressView().frame(maxWidth: .infinity).padding()
                            } else {
                                HStack {
                                    Image(systemName: "doc.on.doc.fill")
                                    Text("Merge Documents & Send").fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                            }
                        }
                        .disabled(isMerging)
                    }
                }
            }
            .navigationTitle("Factor Load #\(entry.loadNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first,
                   url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let data = try? Data(contentsOf: url) {
                        sheetData = data
                        sheetName = url.lastPathComponent
                    }
                }
            }
            .sheet(isPresented: $showReview) {
                if let data = mergedPDF {
                    FactoringReviewView(
                        pdfData: data,
                        defaultSubject: "Load #\(entry.loadNumber) — \(companyInfo.name.isEmpty ? "Good Partners Express LLC" : companyInfo.name)",
                        defaultBody: "Please find the attached factoring packet for Load #\(entry.loadNumber).\n\nCustomer: \(entry.customer)\nRate: $\(entry.originalRate)\nDate: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none))",
                        recipient: companyInfo.factoringEmail
                    ) { sent in
                        if sent {
                            FactoringSheetService.shared.markLoadsAsSubmitted(entries: [entry])
                            onSubmitted()
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    func mergeAndPrepare() {
        guard let sheet = sheetData else { return }
        isMerging = true
        FactoringSheetService.shared.mergePDFs(factoringSheetData: sheet, entries: [entry]) { merged in
            isMerging = false
            if let merged = merged {
                mergedPDF = merged
                showReview = true
            }
        }
    }
}

// MARK: — PDF Preview (reusable PDFKit wrapper)
struct PDFPreviewView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        v.document = PDFDocument(data: data)
        return v
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document == nil { uiView.document = PDFDocument(data: data) }
    }
}

// MARK: — Review screen (PDF preview + editable subject/body before sending)
struct FactoringReviewView: View {
    let pdfData: Data
    let defaultSubject: String
    let defaultBody: String
    let recipient: String
    var onDismiss: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var subject: String = ""
    @State private var bodyText: String = ""
    @State private var showMail = false
    @State private var sentStatus: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PDFPreviewView(data: pdfData)
                    .frame(maxHeight: 360)
                    .background(Color(.systemGray6))

                Form {
                    Section("To") {
                        Text(recipient).foregroundColor(.secondary)
                    }
                    Section("Subject") {
                        TextField("Subject", text: $subject)
                    }
                    Section("Message") {
                        TextEditor(text: $bodyText)
                            .frame(minHeight: 120)
                    }
                    Section {
                        Button {
                            showMail = true
                        } label: {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Send Factoring Packet").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                        }
                        .disabled(!MFMailComposeViewController.canSendMail())
                        if !MFMailComposeViewController.canSendMail() {
                            Text("Mail is not configured on this device.")
                                .font(.caption).foregroundColor(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Review & Send")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss(false); dismiss() }
                }
            }
            .onAppear {
                if subject.isEmpty  { subject  = defaultSubject }
                if bodyText.isEmpty { bodyText = defaultBody }
            }
            .sheet(isPresented: $showMail) {
                FactoringMailView(
                    pdfData: pdfData,
                    recipient: recipient,
                    subject: subject,
                    body: bodyText
                ) { sent in
                    sentStatus = sent
                    onDismiss(sent)
                    if sent { dismiss() }
                }
            }
        }
    }
}

// MARK: — Mail View
struct FactoringMailView: UIViewControllerRepresentable {
    let pdfData: Data; let recipient: String; let subject: String; let body: String; var onDismiss: (Bool)->Void
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController(); vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients([recipient]); vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        let df = DateFormatter(); df.dateFormat = "MMM_d_yyyy"
        vc.addAttachmentData(pdfData, mimeType: "application/pdf", fileName: "Factoring_Packet_\(df.string(from: Date())).pdf")
        return vc
    }
    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDismiss: (Bool)->Void; init(onDismiss: @escaping(Bool)->Void){ self.onDismiss = onDismiss }
        func mailComposeController(_ c: MFMailComposeViewController, didFinishWith r: MFMailComposeResult, error: Error?) { c.dismiss(animated:true); onDismiss(r == .sent) }
    }
}
