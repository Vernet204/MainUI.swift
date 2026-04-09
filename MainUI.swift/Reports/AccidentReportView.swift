import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import CoreLocation

struct AccidentReportView: View {

    @Environment(\.dismiss) var dismiss

    // Driver & Vehicle Info
    @State private var driverName = ""
    @State private var truckID = ""
    @State private var trailerID = ""

    // Incident Details
    @State private var accidentDescription = ""
    @State private var severity = "Minor"
    @State private var injuries = false
    @State private var accidentDate = Date()

    // ✅ Auto GPS location
    @State private var locationString = "Fetching location..."
    @StateObject private var locationManager = LocationManager()

    // Photos
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var uiImages: [UIImage] = []

    // State
    @State private var isSubmitting = false
    @State private var showConfirmation = false
    @State private var errorMessage = ""

    let severityLevels = ["Minor", "Moderate", "Major"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // DRIVER & VEHICLE INFO
                    SectionCard(title: "👤 Driver & Vehicle Info") {
                        VStack(spacing: 12) {
                            TextField("Driver Name", text: $driverName)
                                .textFieldStyle(.roundedBorder)
                            TextField("Truck ID", text: $truckID)
                                .textFieldStyle(.roundedBorder)
                            TextField("Trailer ID", text: $trailerID)
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    // INCIDENT DETAILS — auto stamped
                    SectionCard(title: "🚨 Incident Details") {
                        VStack(alignment: .leading, spacing: 10) {

                            // ✅ Auto date & time stamp
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.blue)
                                Text("Date & Time: \(accidentDate.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.subheadline)
                            }

                            // ✅ Auto GPS location stamp
                            HStack(alignment: .top) {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.green)
                                Text("Location: \(locationString)")
                                    .font(.subheadline)
                                    .foregroundColor(
                                        locationString == "Fetching location..."
                                        ? .gray : .primary
                                    )
                            }
                        }
                    }

                    // SEVERITY
                    SectionCard(title: "⚠️ Severity") {
                        Picker("Severity", selection: $severity) {
                            ForEach(severityLevels, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.segmented)
                    }

                    // INJURIES
                    SectionCard(title: "🩹 Injuries Involved") {
                        Toggle("Were there any injuries?", isOn: $injuries)
                            .font(.headline)
                    }

                    // PHOTO UPLOAD
                    SectionCard(title: "📸 Upload Photos") {
                        PhotosPicker(
                            selection: $selectedImages,
                            maxSelectionCount: 5,
                            matching: .images
                        ) {
                            Label("Add Accident Photos", systemImage: "camera.fill")
                                .font(.headline)
                        }
                        .onChange(of: selectedImages) { newItems in
                            loadImages(from: newItems)
                        }

                        if !uiImages.isEmpty {
                            ScrollView(.horizontal) {
                                HStack {
                                    ForEach(uiImages, id: \.self) { image in
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 100, height: 100)
                                            .cornerRadius(10)
                                            .clipped()
                                    }
                                }
                            }
                        }
                    }

                    // DESCRIPTION
                    SectionCard(title: "📝 Description") {
                        TextEditor(text: $accidentDescription)
                            .frame(height: 120)
                            .padding(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3))
                            )
                    }

                    // ERROR MESSAGE
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }

                    // SUBMIT BUTTON
                    Button(action: submitReport) {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("SUBMIT REPORT")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .cornerRadius(12)
                        }
                    }
                    .disabled(isSubmitting)
                    .padding(.top, 10)
                }
                .padding()
            }
            .navigationTitle("Accident Report")

            // ✅ Start fetching GPS when view appears
            .onAppear {
                locationManager.requestLocation()
            }

            // ✅ Update location string when GPS comes in
            .onChange(of: locationManager.locationString) { newLocation in
                locationString = newLocation
            }
        }
        .alert("Report Submitted", isPresented: $showConfirmation) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your accident report has been submitted successfully.")
        }
    }

    // MARK: - Load Selected Images
    func loadImages(from items: [PhotosPickerItem]) {
        uiImages.removeAll()
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                if case .success(let data?) = result,
                   let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        uiImages.append(image)
                    }
                }
            }
        }
    }

    // MARK: - Submit Report
    func submitReport() {
        guard !driverName.isEmpty else { errorMessage = "Enter driver name."; return }
        guard !truckID.isEmpty else { errorMessage = "Enter truck ID."; return }

        isSubmitting = true
        errorMessage = ""

        if uiImages.isEmpty {
            saveReportToFirestore(imageURLs: [])
        } else {
            uploadImages { imageURLs in
                saveReportToFirestore(imageURLs: imageURLs)
            }
        }
    }

    // MARK: - Save to Firestore
    func saveReportToFirestore(imageURLs: [String]) {
        Firestore.firestore().collection("reports").addDocument(data: [
            "type": "accident",
            "driverName": driverName,
            "truckID": truckID,
            "trailerID": trailerID,
            "severity": severity,
            "injuries": injuries,
            "location": locationString,        // ✅ saves GPS location
            "issueDescription": accidentDescription,
            "accidentDate": Timestamp(date: accidentDate),  // ✅ saves timestamp
            "imageURLs": imageURLs,
            "status": "submitted",
            "dateReported": Timestamp()
        ]) { error in
            DispatchQueue.main.async {
                isSubmitting = false
                if let error = error {
                    errorMessage = "Error: \(error.localizedDescription)"
                } else {
                    showConfirmation = true
                }
            }
        }
    }

    // MARK: - Upload Images
    func uploadImages(completion: @escaping ([String]) -> Void) {
        let storageRef = Storage.storage().reference()
        var uploadedURLs: [String] = []
        let group = DispatchGroup()

        for image in uiImages {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }
            group.enter()
            let imageRef = storageRef.child("accidents/\(UUID().uuidString).jpg")
            imageRef.putData(imageData, metadata: nil) { _, error in
                if let error = error {
                    print("Upload failed: \(error.localizedDescription)")
                    group.leave()
                    return
                }
                imageRef.downloadURL { url, error in
                    if let url = url { uploadedURLs.append(url.absoluteString) }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            completion(uploadedURLs)
        }
    }
}

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    @Published var locationString: String = "Fetching location..."

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    // ✅ Converts GPS coordinates to readable address
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }

        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                let street = placemark.thoroughfare ?? ""
                let city = placemark.locality ?? ""
                let state = placemark.administrativeArea ?? ""

                DispatchQueue.main.async {
                    self.locationString = "\(street), \(city), \(state)"
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationString = "Location unavailable"
        }
        print("Location error: \(error.localizedDescription)")
    }
}

// MARK: - Section Card
struct SectionCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

#Preview {
    AccidentReportView()
}
