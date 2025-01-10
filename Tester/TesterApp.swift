//
//  TesterApp.swift
//  Tester
//
//  Created by Brian Sutton on 1/9/25.
//

import SwiftUI

@main
struct TesterApp: App {
    var body: some Scene {
        Window("QR Scanner", id: "main") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}
