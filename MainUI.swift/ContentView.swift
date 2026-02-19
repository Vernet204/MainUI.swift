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
        NavigationView {
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

                // Hidden Navigation Logic
                NavigationLink(
                    destination: nextView(),
                    isActive: $isLoggedIn
                ) {
                    EmptyView()
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Login Logic (Backend Placeholder)
    func loginUser() {
        // Simulated backend response (REPLACE with real API later)
       // let responseRole = "Driver"
        //let responseFirstLogin = true
       // let responseToken = "xyz123"
        
        // Store backend response into app state
        //userRole = responseRole
        //isFirstLogin = responseFirstLogin
        
        // Optional: Save token for API authentication
       // UserDefaults.standard.set(responseToken, forKey: "authToken")
        
        // Navigate
        isLoggedIn = true
    }

    
    // MARK: - Smart Navigation Routing
    @ViewBuilder
    func nextView() -> some View {
        if isFirstLogin {
            FirstTimePasswordView()
        } else {
            RoleRouterView(role: userRole)
        }
    }
}

#Preview {
    LoginView()
}




// MARK: - REGISTER VIEW
struct RegisterView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var role = " "
    
    let roles = ["Fleet Owner", "Dispatcher", "Driver", ]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Account")
                .font(.title)
                .fontWeight(.bold)
            
            TextField("Full Name", text: $name)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            TextField("Email", text: $email)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            
            Picker("Role", selection: $role) {
                ForEach(roles, id: \.self) { role in
                    Text(role)
                }
            }
            .pickerStyle(.menu)
            
            Button("Register") {}
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






// MARK: - FLEET OWNER DASHBOARD
struct OwnerDashboard: View {
    var body: some View {
        VStack(spacing: 20) {
            
            Text("Fleet Owner Dashboard")
                .font(.title)
                .fontWeight(.bold)
            
            NavigationLink(destination: CreateEmployeeView()) {
                DashboardCard(
                    title: "Create Employee Account",
                    subtitle: "Assign roles to employees",
                    icon: "person.badge.plus",
                    color: .orange
                )
            }
            
            DashboardCard(
                title: "Manage Fleet",
                subtitle: " ",
                icon: "truck.box",
                color: .blue
            )
            DashboardCard(
                title: "View Reports",
                subtitle: " ",
                icon: "chart.bar",
                color: .green
            )
            
            Spacer()
        }
        .padding()
    }
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
            
            NavigationLink(destination: LoadBoardView()) {
                DashboardCard(
                    title: "Load Board",
                    subtitle: "View and manage all loads",
                    icon: "list.bullet.rectangle.fill",
                    color: .orange
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


