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






// MARK: - DISPATCHER DASHBOARD
// MARK: - DISPATCHER DASHBOARD




// MARK: - DRIVER DASHBOARD


// MARK: - ASSIGN LOAD VIEW (YOUR USE CASE)



#Preview {
    ContentView()
        .environmentObject(AppState())
}


