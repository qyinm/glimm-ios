//
//  Memory.swift
//  glimm
//

import Foundation
import SwiftData

@Model
final class Memory {
    var id: UUID
    @Attribute(.externalStorage) var imageData: Data?
    var note: String?
    var capturedAt: Date
    var createdAt: Date

    init(imageData: Data?, note: String? = nil, capturedAt: Date = .now) {
        self.id = UUID()
        self.imageData = imageData
        self.note = note
        self.capturedAt = capturedAt
        self.createdAt = .now
    }
}
