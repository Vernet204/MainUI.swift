//
//  WeeklyInvoiceService.swift
//  MainUI.swift
//
//  Driver-by-driver weekly invoicing.
//  Owner picks a driver, enters that week's fees, generates and emails the invoice.
//

import Foundation
import FirebaseFirestore
import UIKit
import MessageUI
import SwiftUI

// MARK: — Data models
struct InvoiceLoadEntry {
    var pickup:   String
    var delivery: String
    var amount:   Double
}

struct WeeklyFees {
    var gasFees:      Double = 0
    var goodPartners: Double = 125.00
    var insurance:    Double = 1300.00
    var dispatch:     Double = 125.00
    var achTrace:     Double = 3.00
}

struct EmployeeInvoiceData {
    var employeeName:  String
    var employeeEmail: String
    var payPeriodEnd:  Date
    var loads:         [InvoiceLoadEntry]
    var fees:          WeeklyFees

    var grossAmount:   Double { loads.reduce(0) { $0 + $1.amount } }
    var totalExpenses: Double { fees.gasFees + fees.goodPartners + fees.insurance + fees.dispatch }
    var netPay:        Double { grossAmount - totalExpenses }
}

// MARK: — Driver summary (for picker)
struct DriverSummary: Identifiable, Hashable {
    let id: String   // Firestore UID
    var name:  String
    var email: String
}

// MARK: — Invoice Service
class WeeklyInvoiceService {
    static let shared = WeeklyInvoiceService()

    // Fetch all drivers
    func fetchDrivers(completion: @escaping ([DriverSummary]) -> Void) {
        Firestore.firestore().collection("users")
            .whereField("role", isEqualTo: "Driver")
            .getDocuments { snap, _ in
                let drivers: [DriverSummary] = (snap?.documents ?? []).compactMap { doc in
                    let d = doc.data()
                    let name = d["name"] as? String ?? ""
                    guard !name.isEmpty else { return nil }
                    return DriverSummary(
                        id:    doc.documentID,
                        name:  name,
                        email: d["email"] as? String ?? ""
                    )
                }.sorted { $0.name < $1.name }
                DispatchQueue.main.async { completion(drivers) }
            }
    }

    // Fetch this week's delivered loads for one driver
    func fetchLoadsForDriver(
        driverName: String,
        completion: @escaping ([InvoiceLoadEntry]) -> Void
    ) {
        let cal = Calendar.current
        let now = Date()
        guard let weekStart = cal.date(
            from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        ), let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) else {
            completion([]); return
        }

        Firestore.firestore().collection("loads")
            .whereField("status", isEqualTo: "Delivered")
            .whereField("assignedDriver", isEqualTo: driverName)
            .getDocuments { snap, _ in
                let entries: [InvoiceLoadEntry] = (snap?.documents ?? []).compactMap { doc in
                    let d = doc.data()
                    guard let ts = (d["deliveredAt"] as? Timestamp)?.dateValue(),
                          ts >= weekStart && ts < weekEnd else { return nil }
                    return InvoiceLoadEntry(
                        pickup:   d["pickupLocation"]   as? String ?? "",
                        delivery: d["deliveryLocation"] as? String ?? "",
                        amount:   Double(d["rate"] as? String ?? "0") ?? 0
                    )
                }
                DispatchQueue.main.async { completion(entries) }
            }
    }

    // MARK: — Generate PDF matching exact template
    func generateInvoicePDF(data: EmployeeInvoiceData) -> Data {
        let W: CGFloat = 612; let H: CGFloat = 792
        let company = CompanyInfoService.shared.info
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: W, height: H))

        return renderer.pdfData { ctx in
            ctx.beginPage()

            let leftX:   CGFloat = 69;  let midX:    CGFloat = 255
            let amtX:    CGFloat = 398; let dollarX: CGFloat = 260
            let centerX: CGFloat = 237; let expNumX: CGFloat = 86

            func a(_ f: UIFont, _ c: UIColor = .black) -> [NSAttributedString.Key: Any] {
                [.font: f, .foregroundColor: c]
            }
            let f12  = UIFont.systemFont(ofSize: 12)
            let f12b = UIFont.boldSystemFont(ofSize: 12)
            let f11  = UIFont.systemFont(ofSize: 11)
            let f11b = UIFont.boldSystemFont(ofSize: 11)
            let df   = DateFormatter(); df.dateStyle = .medium
            let compName = company.name.isEmpty ? "GoodpartnersExpress, LLC" : company.name

            var y: CGFloat = 91

            compName.draw(at: CGPoint(x: leftX, y: y), withAttributes: a(f12)); y += 17
            "\(compName) Account Payable".draw(at: CGPoint(x: leftX, y: y), withAttributes: a(f12)); y += 17
            (company.fullAddress.isEmpty ? "Owner Address" : company.fullAddress)
                .draw(at: CGPoint(x: leftX, y: y), withAttributes: a(f12b)); y += 16
            (company.email.isEmpty ? "Owner Email" : company.email)
                .draw(at: CGPoint(x: leftX, y: y), withAttributes: a(f12, .systemBlue)); y += 44

            "Payment date: \(df.string(from: data.payPeriodEnd))".draw(at: CGPoint(x: centerX, y: y), withAttributes: a(f12b)); y += 17
            String(format: "Gross Amount: $%.2f", data.grossAmount).draw(at: CGPoint(x: centerX, y: y), withAttributes: a(f12b)); y += 17
            String(format: "Ach Trace: $%.2f", data.fees.achTrace).draw(at: CGPoint(x: centerX, y: y), withAttributes: a(f12b)); y += 44

            "Pick up location".draw(at: CGPoint(x: 104, y: y), withAttributes: a(f11))
            "Delivery Location".draw(at: CGPoint(x: midX, y: y), withAttributes: a(f11b))
            "Amount".draw(at: CGPoint(x: amtX, y: y), withAttributes: a(f11)); y += 22

            UIColor.lightGray.setStroke()
            let sep = UIBezierPath()
            sep.move(to: CGPoint(x: leftX, y: y))
            sep.addLine(to: CGPoint(x: W - leftX, y: y))
            sep.lineWidth = 0.5; sep.stroke(); y += 14

            for (i, load) in data.loads.enumerated() {
                let n = i + 1
                "\(n). \(load.pickup)".draw(at: CGPoint(x: leftX, y: y), withAttributes: a(f11))
                "\(n). \(load.delivery)".draw(at: CGPoint(x: midX, y: y), withAttributes: a(f11))
                String(format: "$%.2f", load.amount).draw(at: CGPoint(x: amtX, y: y), withAttributes: a(f11))
                y += 17
            }

            y += 20
            "Expenses:".draw(at: CGPoint(x: midX, y: y), withAttributes: a(f12b)); y += 28

            let expenses: [(String, Double, Bool)] = [
                ("GAS FEES:", data.fees.gasFees, false),
                ("GOODPARTNERS", data.fees.goodPartners, true),
                ("INSURANCE", data.fees.insurance, true),
                ("DISPATCH", data.fees.dispatch, false)
            ]
            for (i, (desc, amount, isBold)) in expenses.enumerated() {
                let n = data.loads.count + i + 1
                "\(n). \(desc)".draw(at: CGPoint(x: expNumX, y: y), withAttributes: a(isBold ? f11b : f11))
                String(format: "$%.2f", amount).draw(at: CGPoint(x: dollarX, y: y), withAttributes: a(f11))
                y += 32
            }

            y += 30
            "NET ".draw(at: CGPoint(x: 354, y: y), withAttributes: a(f12b))
            let nw = ("NET " as NSString).size(withAttributes: a(f12b)).width
            "PAY ".draw(at: CGPoint(x: 354 + nw, y: y), withAttributes: a(f12))
            let pw = ("PAY " as NSString).size(withAttributes: a(f12)).width
            String(format: "$%.2f", data.netPay).draw(at: CGPoint(x: 354 + nw + pw, y: y), withAttributes: a(f12b))

            let ft: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 8),
                .foregroundColor: UIColor.gray
            ]
            "Driver: \(data.employeeName)  |  Generated by Freight Carrier Assist"
                .draw(at: CGPoint(x: leftX, y: H - 30), withAttributes: ft)
        }
    }
}

// MARK: — Weekly Invoice View (driver-by-driver)
struct WeeklyInvoiceView: View {

    @Environment(\.dismiss) var dismiss
    @StateObject private var compSvc = CompanyInfoService.shared

    // ── Step 1: Driver selection ────────────────────────────
    @State private var drivers:        [DriverSummary] = []
    @State private var selectedDriver: DriverSummary?  = nil
    @State private var isLoadingDrivers = true

    // ── Step 2: Load preview ────────────────────────────────
    @State private var driverLoads:    [InvoiceLoadEntry] = []
    @State private var isLoadingLoads  = false
    @State private var noLoads         = false

    // ── Step 3: Fee input ───────────────────────────────────
    @State private var gasFees      = ""
    @State private var goodPartners = "125.00"
    @State private var insurance    = "1300.00"
    @State private var dispatch     = "125.00"
    @State private var achTrace     = "3.00"

    // ── Step 4: Invoice ─────────────────────────────────────
    @State private var invoiceData:  Data?  = nil
    @State private var driverEmail:  String = ""
    @State private var showMail      = false
    @State private var sentStatus    = ""
    @State private var isGenerating  = false

    var canGenerate: Bool {
        selectedDriver != nil && !driverLoads.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {

                // ── Step 1 — Pick a driver ─────────────────────
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Step 1 — Select Driver", systemImage: "1.circle.fill")
                            .font(.headline).foregroundColor(.blue)
                    }
                    .padding(.vertical, 2)

                    if isLoadingDrivers {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else {
                        Picker("Driver", selection: $selectedDriver) {
                            Text("Select a driver...").tag(Optional<DriverSummary>(nil))
                            ForEach(drivers) { d in
                                Text(d.name).tag(Optional(d))
                            }
                        }
                        .onChange(of: selectedDriver) { _, driver in
                            guard let driver else { driverLoads = []; noLoads = false; return }
                            loadLoadsFor(driver: driver)
                        }
                    }

                    if isLoadingLoads {
                        HStack { ProgressView(); Text("Loading this week's loads...").font(.caption).foregroundColor(.secondary) }
                    } else if let driver = selectedDriver {
                        if noLoads {
                            Text("\(driver.name) has no delivered loads this week.")
                                .font(.caption).foregroundColor(.orange)
                        } else if !driverLoads.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(driverLoads.count) load(s) this week")
                                    .font(.caption).foregroundColor(.green)
                                Text(String(format: "Gross: $%.2f", driverLoads.reduce(0) { $0 + $1.amount }))
                                    .font(.caption).fontWeight(.semibold)
                            }
                        }
                    }
                }

                // ── Step 2 — Enter fees ────────────────────────
                Section {
                    Label("Step 2 — Enter This Week's Fees", systemImage: "2.circle.fill")
                        .font(.headline).foregroundColor(.blue)
                        .padding(.vertical, 2)
                }

                Section("Driver Expenses") {
                    feeRow("Gas Fees ($)", value: $gasFees, placeholder: "0.00")
                }

                Section("Company Deductions") {
                    feeRow("Good Partners ($)",  value: $goodPartners, placeholder: "125.00")
                    feeRow("Insurance ($)",      value: $insurance,    placeholder: "1300.00")
                    feeRow("Dispatch ($)",       value: $dispatch,     placeholder: "125.00")
                    feeRow("ACH Trace ($)",      value: $achTrace,     placeholder: "3.00")
                }

                // ── Step 3 — Generate & email ──────────────────
                Section {
                    Label("Step 3 — Generate & Email", systemImage: "3.circle.fill")
                        .font(.headline).foregroundColor(.blue)
                        .padding(.vertical, 2)

                    if !sentStatus.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            Text(sentStatus).foregroundColor(.green)
                        }
                    }

                    Button {
                        generateInvoice()
                    } label: {
                        if isGenerating {
                            HStack { ProgressView(); Text("Generating...").fontWeight(.semibold) }
                                .frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                Text("Generate Invoice").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(canGenerate ? Color.blue : Color.gray)
                            .foregroundColor(.white).cornerRadius(12)
                        }
                    }
                    .disabled(!canGenerate || isGenerating)

                    if let data = invoiceData {
                        Button {
                            showMail = true
                        } label: {
                            HStack {
                                Image(systemName: "envelope.fill")
                                Text("Email Invoice to \(selectedDriver?.name ?? "Driver")")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.green).foregroundColor(.white).cornerRadius(12)
                        }

                        ShareLink(
                            item: data,
                            preview: SharePreview("\(selectedDriver?.name ?? "Driver") Invoice")
                        ) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Save / Share PDF").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary).cornerRadius(12)
                        }
                    }
                }
            }
            .navigationTitle("Weekly Invoice")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                compSvc.fetch()
                loadDrivers()
            }
            .sheet(isPresented: $showMail) {
                if let data = invoiceData, MFMailComposeViewController.canSendMail() {
                    InvoiceMailView(
                        pdfData:    data,
                        toEmail:    driverEmail,
                        driverName: selectedDriver?.name ?? ""
                    ) { sent in
                        if sent { sentStatus = "✅ Invoice sent to \(driverEmail)" }
                    }
                }
            }
        }
    }

    // MARK: — Fee row helper
    @ViewBuilder
    func feeRow(_ label: String, value: Binding<String>, placeholder: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(placeholder, text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
        }
    }

    // MARK: — Actions
    func loadDrivers() {
        isLoadingDrivers = true
        WeeklyInvoiceService.shared.fetchDrivers { result in
            drivers = result
            isLoadingDrivers = false
        }
    }

    func loadLoadsFor(driver: DriverSummary) {
        isLoadingLoads = true
        noLoads = false
        driverLoads = []
        invoiceData = nil
        sentStatus  = ""
        driverEmail = driver.email

        WeeklyInvoiceService.shared.fetchLoadsForDriver(driverName: driver.name) { loads in
            isLoadingLoads = false
            driverLoads    = loads
            noLoads        = loads.isEmpty
        }
    }

    func generateInvoice() {
        guard let driver = selectedDriver else { return }
        isGenerating = true
        sentStatus   = ""

        let cal = Calendar.current
        let weekEnd = cal.date(byAdding: .day, value: 7,
            to: cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        ) ?? Date()

        let fees = WeeklyFees(
            gasFees:      Double(gasFees)      ?? 0,
            goodPartners: Double(goodPartners)  ?? 125,
            insurance:    Double(insurance)     ?? 1300,
            dispatch:     Double(dispatch)      ?? 125,
            achTrace:     Double(achTrace)      ?? 3
        )

        let data = EmployeeInvoiceData(
            employeeName:  driver.name,
            employeeEmail: driver.email,
            payPeriodEnd:  weekEnd,
            loads:         driverLoads,
            fees:          fees
        )

        invoiceData  = WeeklyInvoiceService.shared.generateInvoicePDF(data: data)
        isGenerating = false
    }
}

// MARK: — Invoice Mail View
struct InvoiceMailView: UIViewControllerRepresentable {
    let pdfData: Data; let toEmail: String; let driverName: String
    var onDismiss: (Bool) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController(); vc.mailComposeDelegate = context.coordinator
        if !toEmail.isEmpty { vc.setToRecipients([toEmail]) }
        vc.setSubject("Good Partners Express LLC — Weekly Pay")
        vc.setMessageBody(
            "Hi \(driverName),\n\nPlease find your weekly pay invoice attached.\n\nThank you,\nGood Partners Express LLC",
            isHTML: false
        )
        let df = DateFormatter(); df.dateFormat = "MMM_d_yyyy"
        vc.addAttachmentData(pdfData, mimeType: "application/pdf",
            fileName: "\(driverName.replacingOccurrences(of: " ", with: "_"))_Invoice_\(df.string(from: Date())).pdf")
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

extension Data: @retroactive Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { $0 }
    }
}
