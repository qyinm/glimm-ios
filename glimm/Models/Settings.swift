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
}
