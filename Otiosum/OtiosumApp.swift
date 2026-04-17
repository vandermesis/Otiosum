//
//  OtiosumApp.swift
//  Otiosum
//
//  Created by Marek Skrzelowski on 16/04/2026.
//

import SwiftUI
import SwiftData

@main
struct OtiosumApp: App {
    @State private var sharedModelContainer = AppConfiguration.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
