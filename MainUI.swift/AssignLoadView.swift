//
//  AssignLoadView.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/10/26.
//

import SwiftUICore
import SwiftUI


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
