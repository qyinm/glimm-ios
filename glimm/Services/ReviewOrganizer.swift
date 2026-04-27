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

struct ReviewHome {
    let hero: Memory?
    let sections: [ReviewSection]
}

struct ReviewNotificationCandidate: Equatable, Identifiable {
    enum Kind: Equatable {
        case memory
        case voiceMemory
        case placeRevisit
    }

    let id: String
    let kind: Kind
    let title: String
    let body: String
    let memoryID: UUID?
    let destination: NotificationDestination
}

struct ReviewSection {
    let reason: ReviewSectionReason
    let memories: [Memory]
    let placeGroups: [PlaceMemoryGroup]

    init(
        reason: ReviewSectionReason,
        memories: [Memory] = [],
        placeGroups: [PlaceMemoryGroup] = []
    ) {
        self.reason = reason
        self.memories = memories
        self.placeGroups = placeGroups
    }
}

enum ReviewSectionReason: Equatable {
    case hero
    case onThisDay
    case fallbackMemory
    case recentWeek
    case voiceMemories
    case locationMemories
    case frequentPlaces
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
    private static let defaultMemorySectionLimit = 6
    private static let defaultPlaceSectionLimit = 6
    private static let reviewPromptMemoryThreshold = 7
    private static let reviewPromptAgeThresholdDays = 7

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

    static func reviewHome(
        from memories: [Memory],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ReviewHome {
        let sorted = sortByRecency(uniqueMemories(memories))
        let hero = sorted.first
        let heroID = hero?.id
        let nonHero = sorted.filter { $0.id != heroID }
        let recentCutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        var sections: [ReviewSection] = []
        if let hero {
            sections.append(ReviewSection(reason: .hero, memories: [hero]))
        }

        let onThisDay = nonHero
            .filter { isOnThisDay($0.capturedAt, now: now, calendar: calendar) }
            .prefix(defaultMemorySectionLimit)
        if !onThisDay.isEmpty {
            sections.append(ReviewSection(reason: .onThisDay, memories: Array(onThisDay)))
        } else if let fallback = nonHero.first(where: { $0.capturedAt <= recentCutoff }) {
            sections.append(ReviewSection(reason: .fallbackMemory, memories: [fallback]))
        }

        let recentWeek = nonHero
            .filter { $0.capturedAt > recentCutoff && $0.capturedAt <= now }
            .prefix(defaultMemorySectionLimit)
        if !recentWeek.isEmpty {
            sections.append(ReviewSection(reason: .recentWeek, memories: Array(recentWeek)))
        }

        let voiceMemories = nonHero
            .filter { $0.audioData != nil }
            .prefix(defaultMemorySectionLimit)
        if !voiceMemories.isEmpty {
            sections.append(ReviewSection(reason: .voiceMemories, memories: Array(voiceMemories)))
        }

        let locationMemories = nonHero
            .filter { hasLocationName($0) }
            .prefix(defaultMemorySectionLimit)
        if !locationMemories.isEmpty {
            sections.append(ReviewSection(reason: .locationMemories, memories: Array(locationMemories)))
        }

        let frequentPlaces = placeGroups(from: nonHero)
            .prefix(defaultPlaceSectionLimit)
        if !frequentPlaces.isEmpty {
            sections.append(ReviewSection(reason: .frequentPlaces, placeGroups: Array(frequentPlaces)))
        }

        return ReviewHome(hero: hero, sections: sections)
    }

    static func reviewNotificationCandidates(
        from memories: [Memory],
        reviewPromptsEnabled: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [ReviewNotificationCandidate] {
        guard reviewPromptsEnabled else { return [] }

        let sorted = sortByRecency(uniqueMemories(memories))

        guard reviewPromptThresholdMet(for: sorted, now: now, calendar: calendar) else {
            return []
        }

        var candidates: [ReviewNotificationCandidate] = []

        if let memory = reviewPromptMemory(from: sorted, now: now, calendar: calendar) {
            candidates.append(
                ReviewNotificationCandidate(
                    id: "memory-\(memory.id.uuidString)",
                    kind: .memory,
                    title: String(localized: "review.notification.memory.title"),
                    body: String(localized: "review.notification.memory.body"),
                    memoryID: memory.id,
                    destination: .reviewHome
                )
            )
        }

        if let voiceMemory = sorted.first(where: { $0.audioData != nil }) {
            candidates.append(
                ReviewNotificationCandidate(
                    id: "voice-\(voiceMemory.id.uuidString)",
                    kind: .voiceMemory,
                    title: String(localized: "review.notification.voice.title"),
                    body: String(localized: "review.notification.voice.body"),
                    memoryID: voiceMemory.id,
                    destination: .reviewHome
                )
            )
        }

        if let placeGroup = placeGroups(from: sorted).first {
            let latestMemory = placeGroup.latestMemory
            candidates.append(
                ReviewNotificationCandidate(
                    id: "place-\(latestMemory.id.uuidString)",
                    kind: .placeRevisit,
                    title: String(localized: "review.notification.place.title"),
                    body: String(localized: "review.notification.place.body"),
                    memoryID: latestMemory.id,
                    destination: .reviewHome
                )
            )
        }

        return candidates
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

            let groupMemories = sortByRecency(value.map(\.1))
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
                if lhs.lastVisitedAt == rhs.lastVisitedAt {
                    return lhs.id < rhs.id
                }
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

    private static func uniqueMemories(_ memories: [Memory]) -> [Memory] {
        var seenIDs = Set<UUID>()
        return memories.filter { memory in
            seenIDs.insert(memory.id).inserted
        }
    }

    private static func sortByRecency(_ memories: [Memory]) -> [Memory] {
        memories.sorted { lhs, rhs in
            if lhs.capturedAt == rhs.capturedAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.capturedAt > rhs.capturedAt
        }
    }

    private static func reviewPromptThresholdMet(
        for sortedMemories: [Memory],
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard let firstMemory = sortedMemories.last else {
            return false
        }

        if sortedMemories.count >= reviewPromptMemoryThreshold {
            return true
        }

        let thresholdDate = calendar.date(
            byAdding: .day,
            value: reviewPromptAgeThresholdDays,
            to: firstMemory.capturedAt
        ) ?? firstMemory.capturedAt
        return thresholdDate <= now
    }

    private static func reviewPromptMemory(
        from sortedMemories: [Memory],
        now: Date,
        calendar: Calendar
    ) -> Memory? {
        let onThisDay = sortedMemories.first {
            isOnThisDay($0.capturedAt, now: now, calendar: calendar)
        }

        if let onThisDay {
            return onThisDay
        }

        let recentCutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        return sortedMemories.first { $0.capturedAt <= recentCutoff } ?? sortedMemories.first
    }

    private static func isOnThisDay(
        _ date: Date,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let memoryComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let nowComponents = calendar.dateComponents([.year, .month, .day], from: now)

        return memoryComponents.month == nowComponents.month &&
            memoryComponents.day == nowComponents.day &&
            memoryComponents.year == (nowComponents.year.map { $0 - 1 })
    }

    private static func hasLocationName(_ memory: Memory) -> Bool {
        guard let locationName = memory.locationName else {
            return false
        }

        return !locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
