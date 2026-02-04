//
//  ExportService.swift
//  glimm
//

import Foundation
import Photos
import UIKit

@MainActor
final class ExportService {
    static let shared = ExportService()

    private init() {}

    // MARK: - Photos Album Export

    func exportToPhotosAlbum(memories: [Memory]) async throws -> Int {
        guard !memories.isEmpty else {
            throw ExportError.noMemories
        }

        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            throw ExportError.photoLibraryAccessDenied
        }

        let albumName = "glimm"
        let album = try await findOrCreateAlbum(named: albumName)

        var savedCount = 0

        for memory in memories {
            guard let imageData = memory.imageData,
                  UIImage(data: imageData) != nil else {
                continue
            }

            try await PHPhotoLibrary.shared().performChanges {
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .photo, data: imageData, options: nil)
                creationRequest.creationDate = memory.capturedAt

                if let placeholder = creationRequest.placeholderForCreatedAsset {
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: album)
                    albumChangeRequest?.addAssets([placeholder] as NSFastEnumeration)
                }
            }

            savedCount += 1
        }

        return savedCount
    }

    private func findOrCreateAlbum(named name: String) async throws -> PHAssetCollection {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", name)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)

        if let existingAlbum = collections.firstObject {
            return existingAlbum
        }

        var placeholder: PHObjectPlaceholder?

        try await PHPhotoLibrary.shared().performChanges {
            let createRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            placeholder = createRequest.placeholderForCreatedAssetCollection
        }

        guard let placeholder = placeholder else {
            throw ExportError.albumCreationFailed
        }

        let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)

        guard let album = fetchResult.firstObject else {
            throw ExportError.albumCreationFailed
        }

        return album
    }

    // MARK: - ZIP Backup Export

    func createBackupArchive(memories: [Memory]) async throws -> URL {
        guard !memories.isEmpty else {
            throw ExportError.noMemories
        }

        let backupName = generateBackupName()
        let backupDir = try createBackupDirectory(named: backupName)

        defer {
            cleanupBackupDirectory(backupDir)
        }

        let metadataEntries = try saveMemoriesToDirectory(memories, at: backupDir)
        try writeMetadataFile(entries: metadataEntries, to: backupDir)

        return try compressToZip(directory: backupDir, named: backupName)
    }

    // MARK: - Private Helpers

    private func generateBackupName() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return "glimm-backup-\(dateFormatter.string(from: Date()))"
    }

    private func createBackupDirectory(named name: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let backupDir = tempDir.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.removeItem(at: backupDir)
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        return backupDir
    }

    private func saveMemoriesToDirectory(_ memories: [Memory], at backupDir: URL) throws -> [[String: Any]] {
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"

        let fileFormatter = DateFormatter()
        fileFormatter.dateFormat = "dd_HH-mm"

        let isoFormatter = ISO8601DateFormatter()

        var metadataEntries: [[String: Any]] = []

        for memory in memories {
            if let entry = try saveMemoryToFile(
                memory: memory,
                in: backupDir,
                monthFormatter: monthFormatter,
                fileFormatter: fileFormatter,
                isoFormatter: isoFormatter
            ) {
                metadataEntries.append(entry)
            }
        }

        return metadataEntries
    }

    private func saveMemoryToFile(
        memory: Memory,
        in backupDir: URL,
        monthFormatter: DateFormatter,
        fileFormatter: DateFormatter,
        isoFormatter: ISO8601DateFormatter
    ) throws -> [String: Any]? {
        guard let imageData = memory.imageData else { return nil }

        let monthFolder = monthFormatter.string(from: memory.capturedAt)
        let monthDir = backupDir.appendingPathComponent(monthFolder, isDirectory: true)

        if !FileManager.default.fileExists(atPath: monthDir.path) {
            try FileManager.default.createDirectory(at: monthDir, withIntermediateDirectories: true)
        }

        var filename = fileFormatter.string(from: memory.capturedAt)
        if let note = memory.note, !note.isEmpty {
            let sanitizedNote = note
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
                .prefix(30)
            filename += "_\(sanitizedNote)"
        }
        filename += ".jpg"

        let filePath = monthDir.appendingPathComponent(filename)
        try imageData.write(to: filePath)

        var entry: [String: Any] = [
            "id": memory.id.uuidString,
            "capturedAt": isoFormatter.string(from: memory.capturedAt),
            "createdAt": isoFormatter.string(from: memory.createdAt),
            "file": "\(monthFolder)/\(filename)"
        ]

        if let note = memory.note {
            entry["note"] = note
        }
        if let lat = memory.latitude, let lon = memory.longitude {
            entry["latitude"] = lat
            entry["longitude"] = lon
        }
        if let locationName = memory.locationName {
            entry["locationName"] = locationName
        }

        return entry
    }

    private func writeMetadataFile(entries: [[String: Any]], to backupDir: URL) throws {
        let metadata: [String: Any] = [
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "appVersion": AppConstants.appVersion,
            "memoriesCount": entries.count,
            "memories": entries
        ]

        let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        let metadataPath = backupDir.appendingPathComponent("metadata.json")
        try metadataData.write(to: metadataPath)
    }

    private func compressToZip(directory: URL, named name: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let zipPath = tempDir.appendingPathComponent("\(name).zip")
        try? FileManager.default.removeItem(at: zipPath)

        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var archiveError: Error?

        coordinator.coordinate(readingItemAt: directory, options: [.forUploading], error: &coordinatorError) { zipURL in
            do {
                try FileManager.default.moveItem(at: zipURL, to: zipPath)
            } catch {
                archiveError = error
            }
        }

        if let error = coordinatorError {
            throw error
        }
        if let error = archiveError {
            throw error
        }

        return zipPath
    }

    private func cleanupBackupDirectory(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
    }
}

// MARK: - Export Errors

enum ExportError: LocalizedError {
    case noMemories
    case photoLibraryAccessDenied
    case albumCreationFailed
    case archiveCreationFailed

    var errorDescription: String? {
        switch self {
        case .noMemories:
            return String(localized: "settings.export.noMemories")
        case .photoLibraryAccessDenied:
            return String(localized: "settings.export.error.photosAccess")
        case .albumCreationFailed:
            return String(localized: "settings.export.error.albumCreation")
        case .archiveCreationFailed:
            return String(localized: "settings.export.error.archiveCreation")
        }
    }
}
