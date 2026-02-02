//
//  Memory.swift
//  glimm
//

import Foundation
import SwiftData

@Model
final class Memory {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var imageData: Data?
    var note: String?
    var capturedAt: Date = Date()
    var createdAt: Date = Date()
    var latitude: Double?
    var longitude: Double?
    var locationName: String?

    init(
        imageData: Data?,
        note: String? = nil,
        capturedAt: Date = .now,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil
    ) {
        self.id = UUID()
        self.imageData = imageData
        self.note = note
        self.capturedAt = capturedAt
        self.createdAt = .now
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
    }
}
