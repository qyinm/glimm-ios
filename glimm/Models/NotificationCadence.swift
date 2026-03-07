//
//  NotificationCadence.swift
//  glimm
//

import Foundation

enum NotificationCadenceMode: String, CaseIterable, Identifiable, Codable {
    case interval
    case customCount

    var id: String { rawValue }
}
