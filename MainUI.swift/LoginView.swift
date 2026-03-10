import SwiftUI
import FirebaseAuth

struct LoginView: View {
    
    @EnvironmentObject var appState: AppState
    
    @State private var email = ""
    @State private var password = ""
    
    // Navigation
    @State private var isLoggedIn = false
    @State private var isFirstLogin = false
    @State private var userRole = "driver"
    @State private var showError = false
    
    var body: some View {
        
        VStack(spacing: 25) {
            
            Spacer()
            
            Text("Freight Carrier Assist")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Company Login Portal")
                .foregroundColor(.gray)
            
            // Email
            TextField("Email Address", text: $email)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .textInputAutocapitalization(.never)
            
            // Password
            SecureField("Password", text: $password)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            if showError {
                Text("Login failed. Check credentials.")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            // Login Button
            Button("Login") {
                loginUser()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding(.top, 10)
            
            Spacer()
        }
        .padding()
        
        // Correct navigation location
        .navigationDestination(isPresented: $isLoggedIn) {
            nextView()
        }
    }
    
    
    // MARK: - Firebase Login
    func loginUser() {
        
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            
            if let error = error {
                print(error.localizedDescription)
                showError = true
                return
            }
            
            // Example user routing
            userRole = "driver"
            isFirstLogin = false
            
            UserDefaults.standard.set("xyz123", forKey: "authToken")
            
            isLoggedIn = true
        }
    }
    
    
    // MARK: - Smart Routing
    @ViewBuilder
    func nextView() -> some View {
        
        if isFirstLogin {
            FirstTimePasswordView(role: userRole)
        } else {
            RoleRouterView(role: userRole)
        }
    }
}