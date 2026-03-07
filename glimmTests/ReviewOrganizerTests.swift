import XCTest
@testable import glimm

final class ReviewOrganizerTests: XCTestCase {
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

    private func makeMemory(
        daysAgo: Int,
        note: String?,
        locationName: String?,
        latitude: Double? = 37.5665,
        longitude: Double? = 126.9780
    ) -> Memory {
        let capturedAt = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        return Memory(
            imageData: Data([0x01]),
            note: note,
            capturedAt: capturedAt,
            latitude: locationName == nil ? nil : latitude,
            longitude: locationName == nil ? nil : longitude,
            locationName: locationName
        )
    }
}
