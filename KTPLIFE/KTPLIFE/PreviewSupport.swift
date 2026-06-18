//
//  PreviewSupport.swift
//  KTPLIFE
//

import SwiftData

@MainActor
enum PreviewModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([Item.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }
    }()
}
