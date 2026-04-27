import XCTest
@testable import glimm

final class ReviewOrganizerTests: XCTestCase {
    private let fixedCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func testHighlightsSplitRecentAndRevisitMemories() {
        let calendar = Calendar.current
        let now = Date()
        let hero = makeMemory(daysAgo: 0, note: "hero", locationName: "Seoul")
        let recent = makeMemory(daysAgo: 2, note: nil, locationName: nil)
        let revisit = makeMemory(daysAgo: 10, note: "old note", locationName: nil)
        let oldWithoutMetadata = makeMemory(daysAgo: 12, note: nil, locationName: nil)

        let highlights = ReviewOrganizer.highlights(
            from: [oldWithoutMetadata, revisit, recent, hero],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(highlights.hero?.id, hero.id)
        XCTAssertEqual(highlights.recent.map(\.id), [recent.id])
        XCTAssertEqual(highlights.revisit.map(\.id), [revisit.id])
    }

    func testPlaceGroupsSortByCountThenRecency() {
        let alphaNewest = makeMemory(daysAgo: 1, note: nil, locationName: "Alpha", latitude: 37.0, longitude: 127.0)
        let alphaOlder = makeMemory(daysAgo: 4, note: nil, locationName: "Alpha", latitude: 37.0, longitude: 127.0)
        let betaOnly = makeMemory(daysAgo: 0, note: nil, locationName: "Beta", latitude: 35.0, longitude: 129.0)

        let groups = ReviewOrganizer.placeGroups(from: [betaOnly, alphaOlder, alphaNewest])

        XCTAssertEqual(groups.map(\.name), ["Alpha", "Beta"])
        XCTAssertEqual(groups.first?.memories.count, 2)
        XCTAssertEqual(groups.first?.latestMemory.id, alphaNewest.id)
    }

    func testPlaceGroupsSplitSameNameAcrossDifferentCoordinateBuckets() {
        let homeNorth = makeMemory(daysAgo: 0, note: nil, locationName: "Home", latitude: 37.5664, longitude: 126.9780)
        let homeSouth = makeMemory(daysAgo: 1, note: nil, locationName: "Home", latitude: 37.5682, longitude: 126.9780)

        let groups = ReviewOrganizer.placeGroups(from: [homeSouth, homeNorth])

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(Set(groups.map(\.id)).count, 2)
        XCTAssertTrue(groups.allSatisfy { $0.name == "Home" })
        XCTAssertEqual(groups.first?.latestMemory.id, homeNorth.id)
    }

    func testPlaceGroupsMergeNearbyCoordinateJitterWithSameName() {
        let officeA = makeMemory(daysAgo: 0, note: nil, locationName: "Office", latitude: 37.56641, longitude: 126.97841)
        let officeB = makeMemory(daysAgo: 2, note: nil, locationName: "Office", latitude: 37.56649, longitude: 126.97849)

        let groups = ReviewOrganizer.placeGroups(from: [officeA, officeB])

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.memories.count, 2)
        XCTAssertEqual(groups.first?.latestMemory.id, officeA.id)
    }

    func testPlaceGroupsUseStableTieBreakerAfterCountAndRecency() {
        let capturedAt = fixedDate(year: 2026, month: 4, day: 27)
        let zeta = makeMemory(capturedAt: capturedAt, note: nil, locationName: "Zeta", latitude: 37.1, longitude: 127.1)
        let alpha = makeMemory(capturedAt: capturedAt, note: nil, locationName: "Alpha", latitude: 37.2, longitude: 127.2)

        let groups = ReviewOrganizer.placeGroups(from: [zeta, alpha])

        XCTAssertEqual(groups.map(\.name), ["Alpha", "Zeta"])
    }

    func testReviewHomePrefersExactOnThisDayMatch() {
        let now = fixedDate(year: 2026, month: 4, day: 27)
        let hero = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 26), note: "hero", locationName: nil)
        let onThisDay = makeMemory(capturedAt: fixedDate(year: 2025, month: 4, day: 27), note: "match", locationName: nil)
        let fallback = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 10), note: "fallback", locationName: nil)

        let home = ReviewOrganizer.reviewHome(
            from: [fallback, onThisDay, hero],
            now: now,
            calendar: fixedCalendar
        )

        XCTAssertEqual(Array(home.sections.map(\.reason).prefix(2)), [.hero, .onThisDay])
        XCTAssertEqual(section(.onThisDay, in: home)?.memories.map(\.id), [onThisDay.id])
        XCTAssertNil(section(.fallbackMemory, in: home))
    }

    func testReviewHomeIncludesSameCalendarDayFromAnyPreviousYear() {
        let now = fixedDate(year: 2026, month: 4, day: 27)
        let hero = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 27), note: "hero", locationName: nil)
        let tooRecent = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 23), note: "recent", locationName: nil)
        let nearestOlder = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 19), note: "nearest", locationName: nil)
        let older = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 1), note: "older", locationName: nil)
        let sameDayTwoYearsAgo = makeMemory(capturedAt: fixedDate(year: 2024, month: 4, day: 27), note: "on this day", locationName: nil)

        let home = ReviewOrganizer.reviewHome(
            from: [sameDayTwoYearsAgo, older, nearestOlder, tooRecent, hero],
            now: now,
            calendar: fixedCalendar
        )

        XCTAssertEqual(section(.onThisDay, in: home)?.memories.map(\.id), [sameDayTwoYearsAgo.id])
        XCTAssertNil(section(.fallbackMemory, in: home))
    }

    func testReviewHomeFallsBackToNearestOlderMemoryAfterSevenDays() {
        let now = fixedDate(year: 2026, month: 4, day: 27)
        let hero = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 27), note: "hero", locationName: nil)
        let tooRecent = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 23), note: "recent", locationName: nil)
        let nearestOlder = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 19), note: "nearest", locationName: nil)
        let older = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 1), note: "older", locationName: nil)

        let home = ReviewOrganizer.reviewHome(
            from: [older, nearestOlder, tooRecent, hero],
            now: now,
            calendar: fixedCalendar
        )

        XCTAssertNil(section(.onThisDay, in: home))
        XCTAssertEqual(section(.fallbackMemory, in: home)?.memories.map(\.id), [nearestOlder.id])
    }

    func testReviewHomeExcludesHeroFromRediscoverySections() {
        let now = fixedDate(year: 2026, month: 4, day: 27)
        let hero = makeMemory(capturedAt: fixedDate(year: 2027, month: 4, day: 27), note: "future hero", locationName: nil)
        let fallback = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 1), note: "fallback", locationName: nil)

        let home = ReviewOrganizer.reviewHome(
            from: [fallback, hero],
            now: now,
            calendar: fixedCalendar
        )

        XCTAssertEqual(home.hero?.id, hero.id)
        XCTAssertEqual(section(.fallbackMemory, in: home)?.memories.map(\.id), [fallback.id])
        XCTAssertFalse(home.sections.dropFirst().flatMap(\.memories).contains { $0.id == hero.id })
    }

    func testReviewHomeIncludesVoiceMemoriesOnlyWhenAudioExists() {
        let now = fixedDate(year: 2026, month: 4, day: 27)
        let hero = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 27), note: "hero", locationName: nil, audioData: Data([0x01]))
        let voice = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 20), note: "voice", locationName: nil, audioData: Data([0x02]))
        let noVoice = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 19), note: "silent", locationName: nil)

        let home = ReviewOrganizer.reviewHome(
            from: [noVoice, voice, hero],
            now: now,
            calendar: fixedCalendar
        )

        XCTAssertEqual(section(.voiceMemories, in: home)?.memories.map(\.id), [voice.id])
    }

    func testReviewHomeIncludesLocationMemoriesOnlyWhenLocationNameExists() {
        let now = fixedDate(year: 2026, month: 4, day: 27)
        let hero = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 27), note: "hero", locationName: "Seoul")
        let withLocation = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 20), note: nil, locationName: "Cafe")
        let withoutLocation = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 19), note: nil, locationName: nil)
        let emptyLocation = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 18), note: nil, locationName: "")

        let home = ReviewOrganizer.reviewHome(
            from: [emptyLocation, withoutLocation, withLocation, hero],
            now: now,
            calendar: fixedCalendar
        )

        XCTAssertEqual(section(.locationMemories, in: home)?.memories.map(\.id), [withLocation.id])
    }

    func testReviewHomeProducesStableSectionOrdering() {
        let now = fixedDate(year: 2026, month: 4, day: 27)
        let hero = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 27), note: "hero", locationName: nil)
        let onThisDay = makeMemory(capturedAt: fixedDate(year: 2025, month: 4, day: 27), note: "match", locationName: nil)
        let recent = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 25), note: "recent", locationName: nil)
        let voice = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 20), note: "voice", locationName: nil, audioData: Data([0x01]))
        let locationA = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 19), note: nil, locationName: "Cafe")
        let locationB = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 18), note: nil, locationName: "Cafe")

        let home = ReviewOrganizer.reviewHome(
            from: [locationB, voice, recent, locationA, onThisDay, hero],
            now: now,
            calendar: fixedCalendar
        )

        XCTAssertEqual(
            home.sections.map(\.reason),
            [.hero, .onThisDay, .recentWeek, .voiceMemories, .locationMemories, .frequentPlaces]
        )
    }

    func testReviewHomeUsesStableIDTieBreakerForSameTimestamp() {
        let now = fixedDate(year: 2026, month: 4, day: 27)
        let capturedAt = fixedDate(year: 2026, month: 4, day: 26)
        let lowerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let higherID = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
        let lower = makeMemory(capturedAt: capturedAt, id: lowerID, note: "lower", locationName: nil)
        let higher = makeMemory(capturedAt: capturedAt, id: higherID, note: "higher", locationName: nil)

        let home = ReviewOrganizer.reviewHome(
            from: [higher, lower],
            now: now,
            calendar: fixedCalendar
        )

        XCTAssertEqual(home.hero?.id, lowerID)
        XCTAssertEqual(section(.recentWeek, in: home)?.memories.map(\.id), [higherID])
    }


    func testReviewNotificationCandidatesAreEmptyWhenDisabled() {
        let now = fixedDate(year: 2026, month: 4, day: 27)
        let memories = (0..<7).map { offset in
            makeMemory(capturedAt: fixedCalendar.date(byAdding: .day, value: -offset, to: now)!, note: "memory", locationName: nil)
        }

        let candidates = ReviewOrganizer.reviewNotificationCandidates(
            from: memories,
            reviewPromptsEnabled: false,
            now: now,
            calendar: fixedCalendar
        )

        XCTAssertTrue(candidates.isEmpty)
    }

    func testReviewNotificationCandidatesAreEmptyBeforeThreshold() {
        let now = fixedDate(year: 2026, month: 4, day: 27)
        let memories = (0..<6).map { offset in
            makeMemory(capturedAt: fixedCalendar.date(byAdding: .day, value: -offset, to: now)!, note: "memory", locationName: nil)
        }

        let candidates = ReviewOrganizer.reviewNotificationCandidates(
            from: memories,
            reviewPromptsEnabled: true,
            now: now,
            calendar: fixedCalendar
        )

        XCTAssertTrue(candidates.isEmpty)
    }

    func testReviewNotificationCandidatesAppearAfterSevenMemories() {
        let now = fixedDate(year: 2026, month: 4, day: 27)
        let memories = (0..<7).map { offset in
            makeMemory(capturedAt: fixedCalendar.date(byAdding: .day, value: -offset, to: now)!, note: "memory", locationName: nil)
        }

        let candidates = ReviewOrganizer.reviewNotificationCandidates(
            from: memories,
            reviewPromptsEnabled: true,
            now: now,
            calendar: fixedCalendar
        )

        XCTAssertEqual(candidates.first?.kind, .memory)
        XCTAssertTrue(candidates.allSatisfy { $0.destination == .reviewHome })
        XCTAssertFalse(candidates.isEmpty)
    }

    func testReviewNotificationCandidatesAppearAfterSevenDaysSinceFirstMemory() {
        let now = fixedDate(year: 2026, month: 4, day: 27)
        let firstMemory = makeMemory(capturedAt: fixedDate(year: 2026, month: 4, day: 20), note: "old enough", locationName: nil)

        let candidates = ReviewOrganizer.reviewNotificationCandidates(
            from: [firstMemory],
            reviewPromptsEnabled: true,
            now: now,
            calendar: fixedCalendar
        )

        XCTAssertEqual(candidates.map(\.kind), [.memory])
        XCTAssertEqual(candidates.first?.memoryID, firstMemory.id)
    }

    func testReviewNotificationPlaceCandidateCopyDoesNotIncludeLocationName() {
        let now = fixedDate(year: 2026, month: 4, day: 27)
        let locationName = "Secret Studio"
        let memories = (0..<7).map { offset in
            makeMemory(
                capturedAt: fixedCalendar.date(byAdding: .day, value: -offset, to: now)!,
                note: nil,
                locationName: locationName,
                latitude: 37.5665,
                longitude: 126.9780
            )
        }

        let candidates = ReviewOrganizer.reviewNotificationCandidates(
            from: memories,
            reviewPromptsEnabled: true,
            now: now,
            calendar: fixedCalendar
        )
        let placeCandidate = candidates.first { $0.kind == .placeRevisit }

        XCTAssertNotNil(placeCandidate)
        XCTAssertFalse(placeCandidate?.id.localizedCaseInsensitiveContains(locationName) ?? true)
        XCTAssertFalse(placeCandidate?.title.localizedCaseInsensitiveContains(locationName) ?? true)
        XCTAssertFalse(placeCandidate?.body.localizedCaseInsensitiveContains(locationName) ?? true)
    }

    private func makeMemory(
        daysAgo: Int,
        note: String?,
        locationName: String?,
        latitude: Double? = 37.5665,
        longitude: Double? = 126.9780,
        audioData: Data? = nil
    ) -> Memory {
        let capturedAt = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        return makeMemory(
            capturedAt: capturedAt,
            note: note,
            locationName: locationName,
            latitude: latitude,
            longitude: longitude,
            audioData: audioData
        )
    }

    private func makeMemory(
        capturedAt: Date,
        id: UUID = UUID(),
        note: String?,
        locationName: String?,
        latitude: Double? = 37.5665,
        longitude: Double? = 126.9780,
        audioData: Data? = nil
    ) -> Memory {
        let memory = Memory(
            imageData: Data([0x01]),
            audioData: audioData,
            note: note,
            capturedAt: capturedAt,
            latitude: locationName == nil ? nil : latitude,
            longitude: locationName == nil ? nil : longitude,
            locationName: locationName
        )
        memory.id = id
        return memory
    }

    private func fixedDate(year: Int, month: Int, day: Int) -> Date {
        fixedCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func section(_ reason: ReviewSectionReason, in home: ReviewHome) -> ReviewSection? {
        home.sections.first { $0.reason == reason }
    }
}
