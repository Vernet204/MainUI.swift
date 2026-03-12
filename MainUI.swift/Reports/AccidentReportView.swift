import SwiftUI
import PhotosUI
import CoreLocation
import FirebaseStorage

struct AccidentReportView: View {
    
    @State private var accidentDescription = ""
    @State private var severity = "Minor"
    @State private var injuries = false
    
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var uiImages: [UIImage] = []
    
    let severityLevels = ["Minor", "Moderate", "Major"]
    
    var body: some View {
        
        NavigationStack {
            
            ScrollView {
                
                VStack(spacing: 20) {
                    
                    // INCIDENT DETAILS
                    SectionCard(title: "🚨 Incident Details") {
                        VStack(alignment: .leading, spacing: 10) {
                            
                            Text("Date & Time: \(Date().formatted(date: .abbreviated, time: .shortened))")
                                .font(.subheadline)
                            
                            Text("Location: Auto GPS Enabled")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // SEVERITY
                    SectionCard(title: "⚠️ Severity") {
                        
                        Picker("Severity", selection: $severity) {
                            ForEach(severityLevels, id: \.self) { level in
                                Text(level)
                            }
                        }
                        .pickerStyle(.segmented)
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
                        
                        ScrollView(.horizontal) {
                            HStack {
                                
                                ForEach(uiImages, id: \.self) { image in
                                    
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .cornerRadius(10)
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
                    
                    // INJURY TOGGLE
                    SectionCard(title: "🩹 Injuries Involved") {
                        
                        Toggle("Were there any injuries?", isOn: $injuries)
                            .font(.headline)
                    }
                    
                    // SUBMIT BUTTON
                    Button(action: submitReport) {
                        
                        Text("SUBMIT REPORT")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                    }
                    .padding(.top, 10)
                    
                }
                .padding()
            }
            .navigationTitle("Accident Report")
        }
    }
    
    // MARK: Load Selected Images
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
    
    
    // MARK: Submit Report
    func submitReport() {
        
        uploadImagesToFirebase()
        
        print("Accident Report Submitted")
        print("Severity: \(severity)")
        print("Injuries: \(injuries)")
        print("Description: \(accidentDescription)")
    }
    
    
    // MARK: Upload Images
    func uploadImagesToFirebase() {
        
        let storageRef = Storage.storage().reference()
        
        for image in uiImages {
            
            if let imageData = image.jpegData(compressionQuality: 0.8) {
                
                let imageRef = storageRef.child("accidents/\(UUID().uuidString).jpg")
                
                imageRef.putData(imageData, metadata: nil) { metadata, error in
                    
                    if let error = error {
                        print("Upload failed:", error.localizedDescription)
                        return
                    }
                    
                    print("Image uploaded successfully")
                }
            }
        }
    }
}



// MARK: Reusable Section Card

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
