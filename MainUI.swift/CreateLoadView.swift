//
//  CreateLoadView.swift
//  MainUI.swift
//
//  Rate con PDF upload → auto-fills all fields + saves to Firebase Storage
//

import SwiftUI
import FirebaseFirestore
import FirebaseStorage
import PDFKit
import UniformTypeIdentifiers

struct CreateLoadView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    // ── Rate Con ──────────────────────────────────────────────
    @State private var showDocumentPicker = false
    @State private var showCamera         = false
    @State private var showPhotoPicker    = false
    @State private var rateConPDFData: Data? = nil
    @State private var rateConFileName = ""
    @State private var isParsing = false
    @State private var parseError = ""
    @State private var parsedSuccessfully = false

    // ── Load Fields (auto-filled from rate con) ───────────────
    @State private var loadID = ""
    @State private var stops: [Stop] = [
        Stop(type: .pickup,   address: "", datetime: Date()),
        Stop(type: .delivery, address: "", datetime: Date().addingTimeInterval(3600 * 8))
    ]
    @State private var weight = ""
    @State private var rate = ""
    @State private var commodity = ""
    @State private var specialInstructions = ""

    // ── Broker / Client ───────────────────────────────────────
    @State private var brokerName = ""
    @State private var brokerEmail = ""
    @State private var brokerAccountingEmail = ""
    @State private var brokerPhone = ""
    @State private var brokerMC = ""
    @State private var brokerDOT = ""
    @State private var brokerContactName = ""
    @State private var clientEmail = ""

    // ── Client picker ─────────────────────────────────────────
    @State private var clients: [ClientOption] = []
    @State private var selectedClient: ClientOption? = nil
    @State private var showAddClient = false

    // ── UI State ──────────────────────────────────────────────
    @State private var errorMessage = ""
    @State private var isCreating = false
    @State private var showManualEntry = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // MARK: - Rate Con Upload Card
                    FormCard(title: "📄 Rate Confirmation") {
                        VStack(spacing: 12) {
                            if rateConPDFData == nil {
                                Text("Capture or upload your rate con — the app auto-fills all load fields.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Button { showCamera = true } label: {
                                    HStack {
                                        Image(systemName: "camera.fill")
                                        Text("Take Photo of Rate Con").fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity).padding()
                                    .background(Color.blue).foregroundColor(.white).cornerRadius(12)
                                }

                                Button { showPhotoPicker = true } label: {
                                    HStack {
                                        Image(systemName: "photo.fill")
                                        Text("Choose from Photo Library").fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity).padding()
                                    .background(Color.purple).foregroundColor(.white).cornerRadius(12)
                                }

                                Button { showDocumentPicker = true } label: {
                                    HStack {
                                        Image(systemName: "doc.fill")
                                        Text("Upload PDF File").fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity).padding()
                                    .background(Color.orange).foregroundColor(.white).cornerRadius(12)
                                }

                                Button {
                                    showManualEntry = true
                                } label: {
                                    Text("Enter manually instead")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                            } else if isParsing {
                                HStack(spacing: 12) {
                                    ProgressView()
                                    Text("Reading rate con...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()

                            } else {
                                HStack(spacing: 10) {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(.blue)
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(rateConFileName.isEmpty ? "Rate Con Uploaded" : rateConFileName)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        if parsedSuccessfully {
                                            Text("✅ Fields auto-filled — review below")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                    }
                                    Spacer()
                                    Button {
                                        rateConPDFData = nil
                                        parsedSuccessfully = false
                                        clearFields()
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .background(Color.blue.opacity(0.06))
                                .cornerRadius(10)
                            }

                            if !parseError.isEmpty {
                                Text(parseError)
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }

                    // MARK: - Load Info (auto-filled)
                    FormCard(title: "Load Info") {
                        VStack(spacing: 12) {
                            TextField("Load ID / Reference Number", text: $loadID)
                                .textInputAutocapitalization(.characters)
                                .textFieldStyle(.roundedBorder)

                            TextField("Commodity / Cargo Type", text: $commodity)
                                .textFieldStyle(.roundedBorder)

                            TextField("Weight (lbs)", text: $weight)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)

                            TextField("Rate ($)", text: $rate)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // MARK: - Broker Info (auto-filled from rate con)
                    FormCard(title: "🏢 Broker / Client Info") {
                        VStack(spacing: 12) {
                            TextField("Broker / Company Name", text: $brokerName)
                                .textFieldStyle(.roundedBorder)

                            TextField("Broker Email", text: $brokerEmail)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .textFieldStyle(.roundedBorder)

                            TextField("Accounting Email (for invoicing)", text: $brokerAccountingEmail)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .textFieldStyle(.roundedBorder)

                            TextField("Broker Phone", text: $brokerPhone)
                                .keyboardType(.phonePad)
                                .textFieldStyle(.roundedBorder)

                            HStack(spacing: 8) {
                                TextField("MC #", text: $brokerMC)
                                    .textFieldStyle(.roundedBorder)
                                TextField("DOT #", text: $brokerDOT)
                                    .textFieldStyle(.roundedBorder)
                            }

                            TextField("Contact Name", text: $brokerContactName)
                                .textFieldStyle(.roundedBorder)

                            // ── Existing client picker ──────────────
                            if !clients.isEmpty {
                                Picker("Link to existing client", selection: $selectedClient) {
                                    Text("Select existing client...").tag(Optional<ClientOption>(nil))
                                    ForEach(clients) { c in
                                        Text(c.companyName).tag(Optional(c))
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                    }

                    // MARK: - Stops (multi-stop editor)
                    FormCard(title: "🗺️ Stops") {
                        StopsEditor(stops: $stops)
                    }

                    // MARK: - Special Instructions
                    FormCard(title: "📋 Special Instructions") {
                        TextField("Any special requirements...", text: $specialInstructions, axis: .vertical)
                            .lineLimit(3...6)
                            .textFieldStyle(.roundedBorder)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }

                    Button(action: createLoad) {
                        if isCreating {
                            ProgressView().frame(maxWidth: .infinity).padding()
                        } else {
                            HStack {
                                Image(systemName: "shippingbox.fill")
                                Text("Create Load").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                    }
                    .disabled(isCreating)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Create Load")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.disabled(isCreating)
                }
            }
            .onAppear { fetchClients() }
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            //  Camera capture — image gets wrapped in a one-page PDF for the parser
            .sheet(isPresented: $showCamera) {
                CameraView { image in handleCapturedImage(image, source: "camera") }
            }
            //  Photo library — same image → PDF path
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPickerView { image in handleCapturedImage(image, source: "library") }
            }
        }
    }

    //  Wrap a captured UIImage in a single-page PDF so parseRateCon(data:) works unchanged.
    func handleCapturedImage(_ image: UIImage, source: String) {
        guard let pdfData = pdfData(from: image) else {
            parseError = "Could not convert image to PDF."
            return
        }
        rateConFileName = source == "camera" ? "Rate Con (camera)" : "Rate Con (photo)"
        rateConPDFData = pdfData
        parseRateCon(data: pdfData)
    }

    func pdfData(from image: UIImage) -> Data? {
        let pageRect = CGRect(origin: .zero, size: image.size)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        return renderer.pdfData { ctx in
            ctx.beginPage()
            image.draw(in: pageRect)
        }
    }

    // MARK: - File Import Handler
    func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try Data(contentsOf: url)
                rateConFileName = url.lastPathComponent
                rateConPDFData = data
                parseRateCon(data: data)
            } catch {
                parseError = "Could not read file: \(error.localizedDescription)"
            }

        case .failure(let error):
            parseError = error.localizedDescription
        }
    }

    // MARK: - Parse Rate Con
    func parseRateCon(data: Data) {
        isParsing = true
        parseError = ""

        DispatchQueue.global(qos: .userInitiated).async {
            let parsed = RateConParserService.shared.parse(pdfData: data)

            DispatchQueue.main.async {
                isParsing = false

                // Auto-fill all fields
                if !parsed.loadNumber.isEmpty      { loadID = parsed.loadNumber }
                if !parsed.rate.isEmpty            { rate = parsed.rate }
                if !parsed.weight.isEmpty          { weight = parsed.weight }
                if !parsed.commodity.isEmpty       { commodity = parsed.commodity }
                if !parsed.brokerName.isEmpty      { brokerName = parsed.brokerName }
                if !parsed.brokerEmail.isEmpty     { brokerEmail = parsed.brokerEmail }
                if !parsed.brokerAccountingEmail.isEmpty { brokerAccountingEmail = parsed.brokerAccountingEmail }
                if !parsed.brokerPhone.isEmpty     { brokerPhone = parsed.brokerPhone }
                if !parsed.brokerMC.isEmpty        { brokerMC = parsed.brokerMC }
                if !parsed.brokerDOT.isEmpty       { brokerDOT = parsed.brokerDOT }
                if !parsed.contactName.isEmpty       { brokerContactName = parsed.contactName }
                clientEmail = parsed.brokerEmail

                //  Prefer the full parsed stops array; otherwise synthesize from the single
                //  pickup/delivery fields that the parser also fills.
                let parsedPickupDT = parseDate(parsed.pickupDate, time: parsed.pickupTime)
                let parsedDeliveryDT = parseDate(parsed.deliveryDate, time: parsed.deliveryTime)
                if !parsed.stops.isEmpty {
                    stops = parsed.stops
                } else {
                    if !parsed.pickupLocation.isEmpty {
                        stops[0].address  = parsed.pickupLocation
                        stops[0].datetime = parsedPickupDT ?? stops[0].datetime
                    }
                    if !parsed.deliveryLocation.isEmpty, stops.count > 1 {
                        stops[1].address  = parsed.deliveryLocation
                        stops[1].datetime = parsedDeliveryDT ?? stops[1].datetime
                    }
                }

                parsedSuccessfully = true

                let hasAnyStopAddr = stops.contains { !$0.address.isEmpty }
                if loadID.isEmpty && !hasAnyStopAddr {
                    parseError = "Could not auto-fill — please review and enter fields manually."
                }
            }
        }
    }

    func parseDate(_ dateStr: String, time: String) -> Date? {
        let formatters = ["MM/dd/yyyy", "M/d/yyyy", "MM-dd-yyyy", "MMMM d, yyyy", "MMM d, yyyy"]
        let combined = time.isEmpty ? dateStr : "\(dateStr) \(time)"
        for format in formatters {
            let df = DateFormatter()
            df.dateFormat = time.isEmpty ? format : "\(format) HH:mm"
            if let date = df.date(from: combined) { return date }
        }
        return nil
    }

    func clearFields() {
        loadID = ""; rate = ""; weight = ""
        commodity = ""; brokerName = ""; brokerEmail = ""; brokerAccountingEmail = ""
        brokerPhone = ""; brokerMC = ""; brokerDOT = ""; brokerContactName = ""
        rateConFileName = ""; parsedSuccessfully = false
        stops = [
            Stop(type: .pickup,   address: "", datetime: Date()),
            Stop(type: .delivery, address: "", datetime: Date().addingTimeInterval(3600 * 8))
        ]
    }

    // MARK: - Fetch Clients
    func fetchClients() {
        Firestore.firestore().collection("clients").getDocuments { snapshot, _ in
            guard let docs = snapshot?.documents else { return }
            DispatchQueue.main.async {
                clients = docs.map { doc in
                    ClientOption(
                        id: doc.documentID,
                        companyName: doc.data()["companyName"] as? String ?? "",
                        brokerName: doc.data()["brokerName"] as? String ?? ""
                    )
                }.filter { !$0.companyName.isEmpty }
            }
        }
    }

    // MARK: - Create Load
    func createLoad() {
        //  Trim empty stops so the dispatcher can add placeholders without a blank entry blocking save.
        let trimmedStops = stops.map {
            var s = $0
            s.address = s.address.trimmingCharacters(in: .whitespaces)
            s.reference = s.reference.trimmingCharacters(in: .whitespaces)
            return s
        }.filter { !$0.address.isEmpty }

        guard trimmedStops.firstPickup != nil else {
            errorMessage = "Add at least one pickup stop."; return
        }
        guard trimmedStops.lastDelivery != nil else {
            errorMessage = "Add at least one delivery stop."; return
        }
        guard !rate.isEmpty else { errorMessage = "Enter rate."; return }
        stops = trimmedStops

        let finalLoadID = loadID.isEmpty
            ? "LD-\(Int.random(in: 1000...9999))"
            : loadID.uppercased().trimmingCharacters(in: .whitespaces)

        isCreating = true
        errorMessage = ""

        // ✅ Check for duplicate load ID
        Firestore.firestore().collection("loads")
            .whereField("loadID", isEqualTo: finalLoadID)
            .getDocuments { snapshot, _ in
                if let docs = snapshot?.documents, !docs.isEmpty {
                    DispatchQueue.main.async {
                        errorMessage = "Load ID \(finalLoadID) already exists."
                        isCreating = false
                    }
                    return
                }

                // ✅ Create or update client profile with broker info
                saveOrUpdateClientProfile()

                // ✅ Upload rate con to Firebase Storage then save load
                if let pdfData = rateConPDFData {
                    uploadRateCon(data: pdfData, loadID: finalLoadID) { rateConURL in
                        saveLoad(finalLoadID: finalLoadID, rateConURL: rateConURL)
                    }
                } else {
                    saveLoad(finalLoadID: finalLoadID, rateConURL: "")
                }
            }
    }

    func uploadRateCon(data: Data, loadID: String, completion: @escaping (String) -> Void) {
        let ref = Storage.storage().reference()
            .child("loads/\(loadID)/ratecon.pdf")
        ref.putData(data, metadata: StorageMetadata()) { _, error in
            if let error = error {
                print("❌ Rate con upload error: \(error.localizedDescription)")
                completion("")
                return
            }
            ref.downloadURL { url, _ in
                completion(url?.absoluteString ?? "")
            }
        }
    }

    func saveLoad(finalLoadID: String, rateConURL: String) {
        let dispatcherName = authManager.appUser?.name ?? "Dispatcher"

        var payload: [String: Any] = [
            "loadID":               finalLoadID,
            "weight":               weight,
            "rate":                 rate,
            "commodity":            commodity,
            "specialInstructions":  specialInstructions,
            "status":               "Unassigned",
            "assignedDriver":       "",
            "assignedDriverID":     "",
            "assignedVehicle":      "",
            "clientID":             selectedClient?.id ?? "",
            "clientName":           brokerName.isEmpty ? (selectedClient?.companyName ?? "") : brokerName,
            "clientEmail":          clientEmail,
            "brokerName":           brokerName,
            "brokerEmail":          brokerEmail,
            "brokerAccountingEmail": brokerAccountingEmail,
            "brokerPhone":          brokerPhone,
            "brokerMC":             brokerMC,
            "brokerDOT":            brokerDOT,
            "brokerContactName":    brokerContactName,
            "rateConURL":           rateConURL,
            "bolURL":               "",
            "signedBolURL":         "",
            "bolSentToBroker":      false,
            "factoringSubmitted":   false,
            "createdBy":            dispatcherName,
            "createdAt":            Timestamp()
        ]
        //  stops array + mirrored first-pickup / last-delivery for queries & sorting
        payload.merge(LoadWrite.stopFields(stops)) { _, new in new }

        Firestore.firestore().collection("loads").addDocument(data: payload) { error in
            DispatchQueue.main.async {
                isCreating = false
                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    dismiss()
                }
            }
        }
    }

    // ✅ Save broker info as a client profile in Firestore
    func saveOrUpdateClientProfile() {
        guard !brokerName.isEmpty else { return }
        let db = Firestore.firestore()

        // Check if client with this name already exists
        db.collection("clients")
            .whereField("companyName", isEqualTo: brokerName)
            .getDocuments { snapshot, _ in
                if let existing = snapshot?.documents.first {
                    // Update with any new info
                    existing.reference.updateData([
                        "brokerEmail":          brokerEmail,
                        "accountingEmail":      brokerAccountingEmail,
                        "phone":                brokerPhone,
                        "mc":                   brokerMC,
                        "dot":                  brokerDOT,
                        "contactName":          brokerContactName,
                        "updatedAt":            Timestamp()
                    ])
                } else {
                    // Create new client profile
                    db.collection("clients").addDocument(data: [
                        "companyName":     brokerName,
                        "brokerName":      brokerName,
                        "email":           brokerEmail,
                        "accountingEmail": brokerAccountingEmail,
                        "phone":           brokerPhone,
                        "mc":              brokerMC,
                        "dot":             brokerDOT,
                        "contactName":     brokerContactName,
                        "createdAt":       Timestamp()
                    ])
                }
            }
    }
}

// MARK: - Stops Editor (shared by Create / Edit)
struct StopsEditor: View {
    @Binding var stops: [Stop]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, _ in
                StopEditorRow(
                    index: index + 1,
                    stop: $stops[index],
                    canRemove: stops.count > 1,
                    onRemove: { stops.remove(at: index) }
                )
            }

            HStack(spacing: 10) {
                Button {
                    stops.append(Stop(
                        type: .pickup,
                        address: "",
                        datetime: stops.last?.datetime ?? Date()
                    ))
                } label: {
                    Label("Add Pickup", systemImage: "mappin.circle")
                        .font(.caption).fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color.green.opacity(0.12))
                        .foregroundColor(.green)
                        .cornerRadius(10)
                }
                Button {
                    stops.append(Stop(
                        type: .delivery,
                        address: "",
                        datetime: (stops.last?.datetime ?? Date()).addingTimeInterval(3600 * 4)
                    ))
                } label: {
                    Label("Add Delivery", systemImage: "mappin.and.ellipse")
                        .font(.caption).fontWeight(.semibold)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Color.red.opacity(0.12))
                        .foregroundColor(.red)
                        .cornerRadius(10)
                }
            }
        }
    }
}

struct StopEditorRow: View {
    let index: Int
    @Binding var stop: Stop
    let canRemove: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("", selection: $stop.type) {
                    ForEach(StopType.allCases) { type in
                        Text(type.label).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)

                Spacer()

                Text("Stop \(index)")
                    .font(.caption).foregroundColor(.secondary)

                if canRemove {
                    Button(role: .destructive) { onRemove() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextField("Address", text: $stop.address)
                .textFieldStyle(.roundedBorder)

            DatePicker("Date & Time", selection: $stop.datetime,
                       displayedComponents: [.date, .hourAndMinute])

            TextField("Reference / PO # (optional)", text: $stop.reference)
                .textFieldStyle(.roundedBorder)
        }
        .padding(10)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
}

// MARK: - Form Card
struct FormCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
        .padding(.horizontal)
    }
}

// MARK: - Client Option Model
struct ClientOption: Identifiable, Hashable {
    let id: String
    var companyName: String
    var brokerName: String
}

// MARK: - Quick Add Client View
struct QuickAddClientView: View {

    @Environment(\.dismiss) var dismiss
    var onAdd: (ClientOption) -> Void

    @State private var companyName = ""
    @State private var brokerName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var errorMessage = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Company Info") {
                    TextField("Company Name", text: $companyName)
                    TextField("Broker Name", text: $brokerName)
                }
                Section("Contact (Optional)") {
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage).foregroundColor(.red).font(.caption)
                    }
                }
                Section {
                    Button { saveClient() } label: {
                        if isSaving {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Client").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.green).foregroundColor(.white).cornerRadius(12)
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle("New Client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    func saveClient() {
        guard !companyName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Company name is required."; return
        }
        guard !brokerName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Broker name is required."; return
        }
        isSaving = true
        errorMessage = ""
        Firestore.firestore()
            .collection("clients")
            .whereField("companyName", isEqualTo: companyName)
            .getDocuments { snapshot, _ in
                if let count = snapshot?.documents.count, count > 0 {
                    DispatchQueue.main.async {
                        errorMessage = "A client named '\(companyName)' already exists."
                        isSaving = false
                    }
                    return
                }
                var ref: DocumentReference?
                ref = Firestore.firestore()
                    .collection("clients")
                    .addDocument(data: [
                        "companyName": companyName.trimmingCharacters(in: .whitespaces),
                        "brokerName":  brokerName.trimmingCharacters(in: .whitespaces),
                        "phone":       phone,
                        "email":       email,
                        "createdAt":   Timestamp()
                    ]) { error in
                        DispatchQueue.main.async {
                            isSaving = false
                            if let error = error {
                                errorMessage = error.localizedDescription
                            } else if let id = ref?.documentID {
                                onAdd(ClientOption(id: id, companyName: companyName, brokerName: brokerName))
                                dismiss()
                            }
                        }
                    }
            }
    }
}

#Preview {
    CreateLoadView()
}
