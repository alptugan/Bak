//
//  BakApp.swift
//  Bak
//
//  Created by alp tugan on 20.02.2026.
//

import SwiftUI

@main
struct BakApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .fixedSize()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
