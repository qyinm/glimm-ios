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
    @Attribute(.externalStorage) var audioData: Data?
    var note: String?
    var audioDuration: Double?
    var capturedAt: Date = Date()
    var createdAt: Date = Date()
    var latitude: Double?
    var longitude: Double?
    var locationName: String?

    init(
        imageData: Data?,
        audioData: Data? = nil,
        note: String? = nil,
        audioDuration: Double? = nil,
        capturedAt: Date = .now,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locationName: String? = nil
    ) {
        self.id = UUID()
        self.imageData = imageData
        self.audioData = audioData
        self.note = note
        self.audioDuration = audioDuration
        self.capturedAt = capturedAt
        self.createdAt = .now
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
    }
}
