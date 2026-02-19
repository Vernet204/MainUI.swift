//
//  MainUI_swiftApp.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/15/26.
//
import SwiftUI

@main
struct MainUI_swiftApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

