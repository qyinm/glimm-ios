//
//  ReviewOrganizer.swift
//  glimm
//

import Foundation
import CoreLocation

struct ReviewHighlights {
    let hero: Memory?
    let recent: [Memory]
    let revisit: [Memory]
}

struct PlaceMemoryGroup: Identifiable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double
    let memories: [Memory]

    var latestMemory: Memory {
        memories.max { $0.capturedAt < $1.capturedAt } ?? memories[0]
    }

    var lastVisitedAt: Date {
        latestMemory.capturedAt
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private struct PlaceGroupKey: Hashable {
    let name: String
    let latitudeBucket: Int
    let longitudeBucket: Int

    var id: String {
        "\(name)|\(latitudeBucket)|\(longitudeBucket)"
    }
}

enum ReviewOrganizer {
    private static let coordinatePrecision: Double = 1_000

    static func highlights(
        from memories: [Memory],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ReviewHighlights {
        let sorted = memories.sorted { $0.capturedAt > $1.capturedAt }
        let hero = sorted.first
        let heroID = hero?.id
        let recentCutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        let recent = sorted
            .filter { $0.id != heroID && $0.capturedAt >= recentCutoff }
            .prefix(6)
        let revisit = sorted
            .filter {
                $0.id != heroID &&
                $0.capturedAt < recentCutoff &&
                (($0.note?.isEmpty == false) || ($0.locationName?.isEmpty == false))
            }
            .prefix(6)

        return ReviewHighlights(
            hero: hero,
            recent: Array(recent),
            revisit: Array(revisit)
        )
    }

    static func placeGroups(from memories: [Memory]) -> [PlaceMemoryGroup] {
        let grouped = Dictionary(grouping: memories.compactMap { memory in
            placeKeyAndMemory(for: memory)
        }) { pair in
            pair.0
        }

        return grouped.compactMap { key, value in
            guard let latest = value
                .map(\.1)
                .max(by: { $0.capturedAt < $1.capturedAt }),
                  let latitude = latest.latitude,
                  let longitude = latest.longitude
            else {
                return nil
            }

            let groupMemories = value.map(\.1).sorted { $0.capturedAt > $1.capturedAt }
            return PlaceMemoryGroup(
                id: key.id,
                name: key.name,
                latitude: latitude,
                longitude: longitude,
                memories: groupMemories
            )
        }
        .sorted { lhs, rhs in
            if lhs.memories.count == rhs.memories.count {
                return lhs.lastVisitedAt > rhs.lastVisitedAt
            }
            return lhs.memories.count > rhs.memories.count
        }
    }

    private static func placeKeyAndMemory(for memory: Memory) -> (PlaceGroupKey, Memory)? {
        guard let name = memory.locationName,
              !name.isEmpty,
              let latitude = memory.latitude,
              let longitude = memory.longitude else {
            return nil
        }

        let key = PlaceGroupKey(
            name: name,
            latitudeBucket: coordinateBucket(latitude),
            longitudeBucket: coordinateBucket(longitude)
        )
        return (key, memory)
    }

    private static func coordinateBucket(_ coordinate: Double) -> Int {
        Int((coordinate * coordinatePrecision).rounded())
    }
}
