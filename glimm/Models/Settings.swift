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
    var notificationCadenceModeRaw: String?
    var notificationIntervalHours: Int?
    var notifyEnabled: Bool = true
    var dualCaptureEnabled: Bool = false

    init() {
        notificationCadenceModeRaw = NotificationCadenceMode.interval.rawValue
        notificationIntervalHours = 3
    }

    var cadenceMode: NotificationCadenceMode {
        NotificationCadenceMode(rawValue: notificationCadenceModeRaw ?? "") ?? .customCount
    }

    var usesLegacyDailyCount: Bool {
        notificationCadenceModeRaw == nil
    }

    var effectiveNotificationIntervalHours: Int {
        notificationIntervalHours ?? 3
    }

    func setCadenceMode(_ mode: NotificationCadenceMode) {
        notificationCadenceModeRaw = mode.rawValue
        if mode == .interval && notificationIntervalHours == nil {
            notificationIntervalHours = 3
        }
    }

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
