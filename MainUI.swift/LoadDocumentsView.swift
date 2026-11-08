//
//  LoadDocumentsView.swift
//  MainUI.swift
//
//  Simplified document flow:
//  — In Transit: driver can view the rate con only
//  — After Delivered: driver uploads signed BOL → app emails it to broker automatically
//

import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import PhotosUI
import MessageUI
import PDFKit
import UniformTypeIdentifiers

struct LoadDocumentsView: View {

    let load: DriverLoad
    @Environment(\.dismiss) var dismiss

    // ── Document URLs ──────────────────────────────────────
    @State private var rateConURL          = ""
    @State private var signedBolURL        = ""
    @State private var bolSentToBroker     = false
    @State private var brokerEmail         = ""
    @State private var brokerAccountingEmail = ""

    // ── Upload state ───────────────────────────────────────
    @State private var isUploading         = false
    @State private var uploadStatus        = ""

    // ── Dispatcher notification ────────────────────────────
    @State private var dispatcherEmail     = ""
    @State private var pendingBolURL       = ""
    @State private var showDispatcherMail  = false

    // ── Sheet toggles ──────────────────────────────────────
    @State private var showCamera          = false
    @State private var showPhotoPicker     = false
    @State private var showFilePicker      = false
    @State private var showRateCon         = false
    @State private var showMailCompose     = false

    var isDelivered: Bool {
        load.status.lowercased() == "delivered"
    }

    var body: some View {
        NavigationStack {
            List {

                // MARK: — Rate Con (view only, always)
                Section("Rate Confirmation") {
                    if rateConURL.isEmpty {
                        HStack {
                            Image(systemName: "doc.fill").foregroundColor(.gray)
                            Text("No rate con on file").foregroundColor(.secondary)
                        }
                    } else {
                        Button {
                            showRateCon = true
                        } label: {
                            HStack {
                                Image(systemName: "doc.fill").foregroundColor(.blue)
                                Text("View Rate Con")
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.gray).font(.caption)
                            }
                        }
                    }
                }

                // MARK: — Signed BOL (only after delivery)
                Section("Signed Bill of Lading") {
                    if !isDelivered {
                        // Not yet delivered — show info message
                        HStack(spacing: 10) {
                            Image(systemName: "lock.fill").foregroundColor(.gray)
                            Text("Signed BOL upload is available after the load is marked Delivered.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else if signedBolURL.isEmpty {
                        // ✅ Delivered — three upload options
                        VStack(spacing: 10) {
                            Button {
                                showCamera = true
                            } label: {
                                HStack {
                                    Image(systemName: "camera.fill")
                                    Text("Take Photo of Signed BOL").fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                            }

                            Button {
                                showPhotoPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "photo.fill")
                                    Text("Choose from Photo Library").fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.purple).foregroundColor(.white).cornerRadius(12)
                            }

                            Button {
                                showFilePicker = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.fill")
                                    Text("Upload File (PDF or Image)").fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.orange).foregroundColor(.white).cornerRadius(12)
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    } else {
                        // ✅ Signed BOL uploaded — dispatcher will email to broker
                        HStack {
                            Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Signed BOL Uploaded")
                                Text("Your dispatcher has been notified and will send this to the broker.")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // ── Upload progress ────────────────────────────────
                if isUploading {
                    Section {
                        HStack {
                            ProgressView()
                            Text(uploadStatus.isEmpty ? "Uploading..." : uploadStatus)
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }

                if !uploadStatus.isEmpty && !isUploading {
                    Section {
                        Text(uploadStatus)
                            .font(.caption)
                            .foregroundColor(uploadStatus.contains("✅") ? .green : .red)
                    }
                }
            }
            .navigationTitle("Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { fetchLoadDetails() }

            // ── Camera ────────────────────────────────────────────
            .sheet(isPresented: $showCamera) {
                CameraView { image in uploadSignedBOL(image: image) }
            }

            // ── Photo library ─────────────────────────────────────
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPickerView { image in uploadSignedBOL(image: image) }
            }

            // ── File importer ─────────────────────────────────────
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [.pdf, .jpeg, .png, .image],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }

            // ── Rate con viewer ───────────────────────────────────
            .sheet(isPresented: $showRateCon) {
                PDFViewerView(urlString: rateConURL, title: "Rate Confirmation")
            }

            // ── Dispatcher notification mail ──────────────────────
            .sheet(isPresented: $showDispatcherMail) {
                if MFMailComposeViewController.canSendMail() {
                    MailComposeView(
                        recipients: [dispatcherEmail],
                        subject: "Load # \(load.loadID) — Signed BOL",
                        body: "Driver has uploaded the signed BOL for Load \(load.loadID).\n\nPlease forward to the broker invoicing email as needed.\n\nGood Partners Express LLC",
                        attachmentURL: pendingBolURL
                    ) { _ in }
                }
            }

            // ── Mail composer ─────────────────────────────────────
            .sheet(isPresented: $showMailCompose) {
                if MFMailComposeViewController.canSendMail() {
                    MailComposeView(
                        recipients: emailRecipients,
                        subject: "Load # \(load.loadID)",
                        body: "Please find the signed Bill of Lading attached for Load \(load.loadID).\n\nThank you,\nGood Partners Express LLC",
                        attachmentURL: signedBolURL
                    ) { sent in
                        if sent { markBOLSent() }
                    }
                }
            }
        }
    }

    // MARK: — Helpers

    var emailRecipients: [String] {
        var r: [String] = []
        if !brokerEmail.isEmpty { r.append(brokerEmail) }
        if !brokerAccountingEmail.isEmpty && brokerAccountingEmail != brokerEmail {
            r.append(brokerAccountingEmail)
        }
        return r
    }

    func fetchLoadDetails() {
        Firestore.firestore().collection("loads").document(load.id).getDocument { snap, _ in
            guard let d = snap?.data() else { return }
            DispatchQueue.main.async {
                rateConURL            = d["rateConURL"]            as? String ?? ""
                signedBolURL          = d["signedBolURL"]          as? String ?? ""
                bolSentToBroker       = d["bolSentToBroker"]       as? Bool   ?? false
                brokerEmail           = d["brokerEmail"]           as? String ?? ""
                brokerAccountingEmail = d["brokerAccountingEmail"] as? String ?? ""
            }
        }
    }

    // MARK: — Upload from camera/photo library
    func uploadSignedBOL(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        isUploading = true; uploadStatus = "Uploading signed BOL..."

        let ref = Storage.storage().reference()
            .child("loads/\(load.loadID)/bol_signed.jpg")

        ref.putData(data) { _, error in
            if let error = error {
                DispatchQueue.main.async {
                    isUploading = false
                    uploadStatus = "Upload failed: \(error.localizedDescription)"
                }
                return
            }
            ref.downloadURL { url, _ in
                guard let urlStr = url?.absoluteString else { return }
                saveSignedBolURL(urlStr)
            }
        }
    }

    // MARK: — Upload from file
    func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first,
                  url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else {
                uploadStatus = "Could not read file."; return
            }
            isUploading = true; uploadStatus = "Uploading signed BOL..."

            let ext  = url.pathExtension.lowercased() == "pdf" ? "pdf" : "jpg"
            let mime = ext == "pdf" ? "application/pdf" : "image/jpeg"
            let ref  = Storage.storage().reference()
                .child("loads/\(load.loadID)/bol_signed.\(ext)")

            ref.putData(data, metadata: { let m = StorageMetadata(); m.contentType = mime; return m }()) { _, error in
                if let error = error {
                    DispatchQueue.main.async {
                        isUploading = false
                        uploadStatus = "Upload failed: \(error.localizedDescription)"
                    }
                    return
                }
                ref.downloadURL { url, _ in
                    guard let urlStr = url?.absoluteString else { return }
                    saveSignedBolURL(urlStr)
                }
            }
        case .failure(let error):
            uploadStatus = "Error: \(error.localizedDescription)"
        }
    }

    func saveSignedBolURL(_ urlStr: String) {
        Firestore.firestore().collection("loads").document(load.id)
            .updateData([
                "signedBolURL": urlStr,
                "bolSentToBroker": false  // dispatcher will send it
            ]) { _ in
                DispatchQueue.main.async {
                    self.isUploading  = false
                    self.signedBolURL = urlStr
                    self.uploadStatus = "✅ Signed BOL uploaded — dispatcher has been notified"
                }
            }
    }

    // ✅ Email signed BOL copy to dispatcher so they can forward to broker invoicing
    func notifyDispatcher(signedBolURL: String) {
        guard MFMailComposeViewController.canSendMail() else { return }
        // Fetch dispatcher email from load's createdBy / assignedBy field
        Firestore.firestore().collection("loads").document(load.id).getDocument { snap, _ in
            guard let d = snap?.data() else { return }
            let dispatcherName = d["createdBy"] as? String ?? d["assignedBy"] as? String ?? ""
            guard !dispatcherName.isEmpty else { return }
            // Look up dispatcher email
            Firestore.firestore().collection("users")
                .whereField("name", isEqualTo: dispatcherName)
                .getDocuments { userSnap, _ in
                    guard let dispatcherEmail = userSnap?.documents.first?.data()["email"] as? String,
                          !dispatcherEmail.isEmpty else { return }
                    DispatchQueue.main.async {
                        self.dispatcherEmail  = dispatcherEmail
                        self.pendingBolURL    = signedBolURL
                        self.showDispatcherMail = true
                    }
                }
        }
    }

    func markBOLSent() {
        Firestore.firestore().collection("loads").document(load.id)
            .updateData(["bolSentToBroker": true, "bolSentAt": Timestamp()]) { _ in
                DispatchQueue.main.async { bolSentToBroker = true }
            }
    }
}

// MARK: — Camera View
struct CameraView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .camera; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ p: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }
        func imagePickerController(_ p: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { onCapture(img) }
            p.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ p: UIImagePickerController) { p.dismiss(animated: true) }
    }
}

// MARK: — Photo Picker View
struct PhotoPickerView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var cfg = PHPickerConfiguration(); cfg.filter = .images; cfg.selectionLimit = 1
        let p = PHPickerViewController(configuration: cfg); p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ p: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onCapture: (UIImage) -> Void
        init(onCapture: @escaping (UIImage) -> Void) { self.onCapture = onCapture }
        func picker(_ p: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            p.dismiss(animated: true)
            guard let r = results.first else { return }
            r.itemProvider.loadObject(ofClass: UIImage.self) { obj, _ in
                if let img = obj as? UIImage { DispatchQueue.main.async { self.onCapture(img) } }
            }
        }
    }
}

// MARK: — PDF Viewer
struct PDFViewerView: View {
    let urlString: String; let title: String
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            Group {
                if let url = URL(string: urlString) { PDFKitView(url: url) }
                else { Text("Unable to load document").foregroundColor(.secondary) }
            }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView {
        let v = PDFView(); v.autoScales = true
        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data, let doc = PDFDocument(data: data) {
                DispatchQueue.main.async { v.document = doc }
            }
        }.resume()
        return v
    }
    func updateUIView(_ v: PDFView, context: Context) {}
}

// MARK: — Mail Compose View
struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]; let subject: String; let body: String
    let attachmentURL: String; var onDismiss: (Bool) -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController(); vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients); vc.setSubject(subject); vc.setMessageBody(body, isHTML: false)
        // Attach signed BOL
        if !attachmentURL.isEmpty, let url = URL(string: attachmentURL),
           let data = try? Data(contentsOf: url) {
            let isPDF = attachmentURL.lowercased().contains(".pdf")
            vc.addAttachmentData(data,
                mimeType: isPDF ? "application/pdf" : "image/jpeg",
                fileName: isPDF ? "SignedBOL.pdf" : "SignedBOL.jpg")
        }
        return vc
    }
    func updateUIViewController(_ vc: MFMailComposeViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDismiss: (Bool) -> Void
        init(onDismiss: @escaping (Bool) -> Void) { self.onDismiss = onDismiss }
        func mailComposeController(_ c: MFMailComposeViewController, didFinishWith r: MFMailComposeResult, error: Error?) {
            c.dismiss(animated: true); onDismiss(r == .sent)
        }
    }
}
