//
//  Settings.swift
//  glimm
//

import Foundation
import SwiftData

@Model
final class Settings {
    var id: UUID = UUID()
    var notifyStart: Date = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
    var notifyEnd: Date = Calendar.current.date(from: DateComponents(hour: 21, minute: 0)) ?? Date()
    var notifyFrequency: Int = 3
    var notifyEnabled: Bool = true

    init() {}

    /// Gets the existing Settings or creates a new one if none exists
    @MainActor
    static func getOrCreate(in context: ModelContext) -> Settings {
        let descriptor = FetchDescriptor<Settings>()
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let newSettings = Settings()
        context.insert(newSettings)
        return newSettings
    }
}
