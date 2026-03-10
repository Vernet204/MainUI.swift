//
//  MainUI_swiftApp.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/15/26.
//
import SwiftUI
import FirebaseCore

@main
struct MainUI_swiftApp: App {

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
