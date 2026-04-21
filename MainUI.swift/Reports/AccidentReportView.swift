import SwiftUI
import PhotosUI
import FirebaseStorage
import FirebaseFirestore
import CoreLocation

struct AccidentReportView: View {

    @Environment(\.dismiss) var dismiss

    // ✅ Picker selections
    @State private var selectedDriver: ReportDriver? = nil
    @State private var selectedVehicle: ReportVehicle? = nil
    @State private var drivers: [ReportDriver] = []
    @State private var vehicles: [ReportVehicle] = []

    // Incident Details
    @State private var accidentDescription = ""
    @State private var severity = "Minor"
    @State private var injuries = false
    @State private var accidentDate = Date()

    // GPS
    @State private var locationString = "Fetching location..."
    @StateObject private var locationManager = LocationManager()

    // Photos
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var uiImages: [UIImage] = []

    // State
    @State private var isSubmitting = false
    @State private var showConfirmation = false
    @State private var errorMessage = ""  // ✅ Only one declaration

    let severityLevels = ["Minor", "Moderate", "Major"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // DRIVER & VEHICLE
                    SectionCard(title: "👤 Driver & Vehicle") {
                        VStack(alignment: .leading, spacing: 12) {
                            Picker("Select Driver", selection: $selectedDriver) {
                                Text("Select a driver...").tag(Optional<ReportDriver>(nil))
                                ForEach(drivers) { driver in
                                    Text(driver.name).tag(Optional(driver))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Picker("Select Truck", selection: $selectedVehicle) {
                                Text("Select a vehicle...").tag(Optional<ReportVehicle>(nil))
                                ForEach(vehicles) { vehicle in
                                    Text("\(vehicle.unitNumber) — \(vehicle.plate)").tag(Optional(vehicle))
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    // INCIDENT DETAILS
                    SectionCard(title: "🚨 Incident Details") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .foregroundColor(.blue)
                                Text("Date & Time: \(accidentDate.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.subheadline)
                            }
                            HStack(alignment: .top) {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.green)
                                Text("Location: \(locationString)")
                                    .font(.subheadline)
                                    .foregroundColor(
                                        locationString == "Fetching location..." ? .gray : .primary
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

                    // ERROR
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }

                    // SUBMIT
                    Button(action: submitReport) {
                        if isSubmitting {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.6))
                                .cornerRadius(12)
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
            .onAppear {
                locationManager.requestLocation()
                fetchDrivers()
                fetchVehicles()
            }
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

    // MARK: - Fetch Drivers
    func fetchDrivers() {
        Firestore.firestore()
            .collection("users")
            .whereField("role", isEqualTo: "Driver")
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    drivers = docs.map {
                        ReportDriver(
                            id: $0.documentID,
                            name: $0.data()["name"] as? String ?? ""
                        )
                    }.filter { !$0.name.isEmpty }
                }
            }
    }

    // MARK: - Fetch Vehicles
    func fetchVehicles() {
        Firestore.firestore()
            .collection("vehicles")
            .getDocuments { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                DispatchQueue.main.async {
                    vehicles = docs.map { doc in
                        let d = doc.data()
                        return ReportVehicle(
                            id: doc.documentID,
                            unitNumber: d["unitNumber"] as? String ?? "",
                            plate: d["plate"] as? String ?? ""
                        )
                    }.filter { !$0.unitNumber.isEmpty }
                }
            }
    }

    // MARK: - Load Images
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
        guard let driver = selectedDriver else {
            errorMessage = "Please select a driver."
            return
        }
        guard let vehicle = selectedVehicle else {
            errorMessage = "Please select a vehicle."
            return
        }
        errorMessage = ""
        isSubmitting = true

        let reportNumber = "ACC-\(Int.random(in: 1000...9999))"

        let reportData: [String: Any] = [
            "reportNumber": reportNumber,
            "type": "accident",
            "driverName": driver.name,
            "truckID": vehicle.unitNumber,
            "vehicleNumber": vehicle.unitNumber,
            "severity": severity,
            "injuries": injuries,
            "accidentDescription": accidentDescription,
            "location": locationString,
            "accidentDate": Timestamp(date: accidentDate),
            "dateReported": Timestamp(),
            "status": "Open"
        ]

        Firestore.firestore()
            .collection("reports")
            .addDocument(data: reportData) { error in
                DispatchQueue.main.async {
                    isSubmitting = false
                    if let error = error {
                        errorMessage = "Error: \(error.localizedDescription)"
                        return
                    }
                    // ✅ Moderate/Major → vehicle In Maintenance
                    if self.severity == "Moderate" || self.severity == "Major" {
                        Firestore.firestore()
                            .collection("vehicles")
                            .document(vehicle.id)
                            .updateData([
                                "status": "In Maintenance",
                                "inspectionStatus": "Accident Reported"
                            ])
                    }
                    showConfirmation = true
                }
            }

        // ✅ Upload photos
        if !uiImages.isEmpty {
            let storageRef = Storage.storage().reference()
            for image in uiImages {
                if let imageData = image.jpegData(compressionQuality: 0.8) {
                    let imageRef = storageRef.child("accidents/\(UUID().uuidString).jpg")
                    imageRef.putData(imageData, metadata: nil) { _, error in
                        if let error = error {
                            print("Upload failed:", error.localizedDescription)
                        }
                    }
                }
            }
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

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
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
