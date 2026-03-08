//
//  DashboardCard.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 3/7/26.
//


import SwiftUI

struct DashboardCard: View {
    
    var title: String
    var icon: String
    var color: Color
    
    var body: some View {
        
        HStack {
            
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(color)
                .cornerRadius(12)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }
}