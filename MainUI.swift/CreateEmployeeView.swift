//
//  CreateEmployeeView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/15/26.
//


import SwiftUI

struct CreateEmployeeView: View {
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var selectedRole = "Driver"
    @State private var tempPassword = ""
    
    let roles = ["Driver", "Dispatcher", "Broker"]
    
    var body: some View {
        VStack(spacing: 20) {
            
            // Header
            Text("Create Employee Account")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Fleet Owner Panel")
                .foregroundColor(.gray)
            
            // Form Section
            VStack(spacing: 15) {
                
                TextField("Full Name", text: $fullName)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                
                TextField("Email Address", text: $email)
                    .keyboardType(.emailAddress)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                
                TextField("Phone Number", text: $phone)
                    .keyboardType(.phonePad)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                
                SecureField("Temporary Password", text: $tempPassword)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                
                // Role Picker
                VStack(alignment: .leading) {
                    Text("Assign Role")
                        .font(.headline)
                    
                    Picker("Role", selection: $selectedRole) {
                        ForEach(roles, id: \.self) { role in
                            Text(role)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.top, 5)
            }
            .padding(.horizontal)
            
            // Create Button
            Button(action: {
                createEmployee()
            }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("Create Employee Account")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(14)
            }
            .padding(.horizontal)
            
            // Info Box (Business Logic Hint)
            VStack(alignment: .leading, spacing: 8) {
                Text("System Behavior:")
                    .font(.headline)
                
                Text("• Employee will receive login credentials")
                Text("• Employee must change password on first login")
                Text("• Role determines dashboard access")
            }
            .font(.caption)
            .foregroundColor(.gray)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    func createEmployee() {
        // Future: Connect to Firebase / Backend
        print("Creating \(selectedRole): \(fullName)")
    }
}

#Preview {
    CreateEmployeeView()
        .environmentObject(AppState())
}

