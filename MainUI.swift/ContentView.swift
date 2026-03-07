//
//  ContentView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/15/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appState = AppState()

    var body: some View {
        NavigationStack {
            LoginView()
            
        }
        .environmentObject(appState)
    }
}


// MARK: - LOGIN VIEW
import SwiftUI

struct LoginView: View {
    
    @State private var email = ""
    @State private var password = ""
    
    // Navigation States
    @State private var isLoggedIn = false
    @State private var isFirstLogin = false
    @State private var userRole = ""
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
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
                    .autocapitalization(.none)
                
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
                
                // 🔐 Real Login Button (Backend Ready)
                Button("Login") {
                    loginUser()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.top, 10)
                
                Button("Register") {
                    RegisterView()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.top, 10)

                // Hidden Navigation Logic
                .navigationDestination(isPresented: $isLoggedIn) {
                    if isFirstLogin {
                        FirstTimePasswordView(role: userRole)
                    } else {
                        RoleRouterView(role: userRole)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Login Logic (Backend Placeholder)
    func loginUser() {

        // simulate backend
        userRole = " "
        isFirstLogin = true

        UserDefaults.standard.set("xyz123", forKey: "authToken")

        isLoggedIn = true
    }

    
    // MARK: - Smart Navigation Routing
    @ViewBuilder
    func nextView() -> some View {
        if isFirstLogin {
            FirstTimePasswordView(role: userRole)
        } else {
            RoleRouterView(role: userRole)
        }
    }
}

#Preview {
    LoginView()
}







// MARK: - DISPATCHER DASHBOARD
// MARK: - DISPATCHER DASHBOARD
struct DispatcherDashboard: View {
    @State private var loads: [Load] = []
    var body: some View {
        VStack(spacing: 20) {
            
            Text("Dispatcher Dashboard")
                .font(.title)
                .fontWeight(.bold)
            
            NavigationLink(destination: CreateLoadView()) {
                DashboardCard(
                    title: "Create Load",
                    subtitle: "Add new freight",
                    icon: "plus.rectangle.fill",
                    color: .blue
                )
            }
            
          
            NavigationLink(destination: AssignLoadView()) {
                DashboardCard(
                    title: "Assign Drivers",
                    subtitle: " ",
                    icon: "person.2.fill",
                    color: .green
                )
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Dispatcher")
    }
}



// MARK: - DRIVER DASHBOARD
struct DriverDashboard: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Driver Dashboard")
                .font(.title)
                .fontWeight(.bold)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - ASSIGN LOAD VIEW (YOUR USE CASE)
struct AssignLoadView: View {
    @State private var loadID = ""
    @State private var driverName = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Assign Load to Driver")
                .font(.title)
                .fontWeight(.bold)
            
            TextField("Load ID", text: $loadID)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            TextField("Driver Name", text: $driverName)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            Button("Assign Load") {}
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
            
            Spacer()
        }
        .padding()
    }
}


#Preview {
    ContentView()
        .environmentObject(AppState())
}


