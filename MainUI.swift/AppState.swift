//
//  AppState.swift
//  MainUI.swift
//
//  Created by lounyveson vernet on 2/18/26.
//


import Foundation
import SwiftUI

final class AppState: ObservableObject {
    @Published var loads: [Load] = []
}

