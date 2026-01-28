//
//  Settings.swift
//  glimm
//

import Foundation
import SwiftData

@Model
final class Settings {
    var id: UUID
    var notifyStart: Date
    var notifyEnd: Date
    var notifyFrequency: Int
    var notifyEnabled: Bool

    init() {
        self.id = UUID()
        let calendar = Calendar.current
        self.notifyStart = calendar.date(from: DateComponents(hour: 9, minute: 0)) ?? .now
        self.notifyEnd = calendar.date(from: DateComponents(hour: 21, minute: 0)) ?? .now
        self.notifyFrequency = 3
        self.notifyEnabled = true
    }
}
