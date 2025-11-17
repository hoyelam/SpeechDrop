//
//  SpeechDropApp.swift
//  SpeechDrop
//
//  Created by Hoye Lam on 16/11/2025.
//

import SwiftUI
import Dependencies
import GRDB
import SQLiteData

@main
struct SpeechDropApp: App {
    init() {
        prepareDependencies {
            do {
                let db = try appDatabase()
                $0.defaultDatabase = db

                // Insert sample data on first launch
                Task {
                    try await insertSampleData(into: db)
                }
            } catch {
                fatalError("Failed to initialize database: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
