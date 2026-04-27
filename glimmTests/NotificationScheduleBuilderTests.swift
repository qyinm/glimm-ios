import XCTest
@testable import glimm

final class NotificationScheduleBuilderTests: XCTestCase {
    func testIntervalRangesReserveMinimumGapBetweenBuckets() {
        let start = makeTime(hour: 9, minute: 0)
        let end = makeTime(hour: 21, minute: 0)

        let ranges = NotificationScheduleBuilder.intervalRanges(
            start: start,
            end: end,
            intervalHours: 3
        )

        XCTAssertEqual(ranges.count, 4)
        XCTAssertEqual(ranges[0], 540..<690)
        XCTAssertEqual(ranges[1], 720..<870)
        XCTAssertEqual(ranges[2], 900..<1050)
        XCTAssertEqual(ranges[3], 1080..<1230)
    }

    func testCustomCountProducesRequestedNumberOfDailySlotsWhenWindowAllowsIt() {
        let start = makeTime(hour: 9, minute: 0)
        let end = makeTime(hour: 18, minute: 0)

        let ranges = NotificationScheduleBuilder.countRanges(
            start: start,
            end: end,
            count: 3
        )

        XCTAssertEqual(ranges.count, 3)
        XCTAssertEqual(ranges[0], 540..<690)
        XCTAssertEqual(ranges[1], 720..<870)
        XCTAssertEqual(ranges[2], 900..<1050)
    }

    func testCustomCountDropsImpossibleSlotsWhenWindowIsTooShort() {
        let start = makeTime(hour: 9, minute: 0)
        let end = makeTime(hour: 10, minute: 0)

        let ranges = NotificationScheduleBuilder.countRanges(
            start: start,
            end: end,
            count: 3
        )

        XCTAssertTrue(ranges.isEmpty)
    }

    func testNotificationDestinationBuildsNamespacedIdentifiers() {
        let identifier = NotificationDestination.capture.makeIdentifier(id: "abc")

        XCTAssertEqual(identifier, "glimm.capture.abc")
        XCTAssertTrue(NotificationDestination.capture.matches(identifier: identifier))
        XCTAssertFalse(NotificationDestination.reviewHome.matches(identifier: identifier))
    }

    func testNotificationDestinationRoundTripsThroughPayload() {
        let payload = NotificationDestination.capture.userInfo

        XCTAssertEqual(NotificationDestination(userInfo: payload), .capture)
    }

    func testNotificationRouteCarriesMemoryIDPayload() {
        let memoryID = UUID()
        let payload = NotificationDestination.memoryDetail.userInfo(memoryID: memoryID)
        let route = NotificationRoute(userInfo: payload)

        XCTAssertEqual(route.destination, .memoryDetail)
        XCTAssertEqual(route.memoryID, memoryID)
    }

    func testNotificationRouteIgnoresInvalidMemoryIDPayload() {
        let payload: [AnyHashable: Any] = [
            "notificationKind": "memoryDetail",
            "memoryID": "not-a-uuid"
        ]
        let route = NotificationRoute(userInfo: payload)

        XCTAssertEqual(route.destination, .memoryDetail)
        XCTAssertNil(route.memoryID)
    }

    func testUnknownNotificationPayloadFallsBackToCaptureForExistingNotifications() {
        XCTAssertEqual(NotificationDestination(userInfo: [:]), .capture)
        XCTAssertEqual(NotificationDestination(userInfo: ["notificationKind": "unknown"]), .capture)
    }

    func testCaptureCancellationIncludesLegacyBareIdentifiersOnly() {
        let identifiers = [
            "glimm.capture.new-capture",
            "C5D7F3B1-064F-44A5-BE16-F9D8DBDD983F",
            "foreign-system-notification",
            "glimm.reviewHome.review",
            "glimm.memoryDetail.memory"
        ]

        XCTAssertEqual(
            NotificationDestination.identifiersToCancel(for: .capture, from: identifiers),
            [
                "glimm.capture.new-capture",
                "C5D7F3B1-064F-44A5-BE16-F9D8DBDD983F"
            ]
        )
    }

    func testReviewCancellationDoesNotIncludeCaptureIdentifiers() {
        let identifiers = [
            "glimm.capture.keep-capture",
            "C5D7F3B1-064F-44A5-BE16-F9D8DBDD983F",
            "glimm.reviewHome.review-memory",
            "glimm.memoryDetail.review-memory"
        ]

        XCTAssertEqual(
            NotificationDestination.reviewIdentifiersToCancel(from: identifiers),
            [
                "glimm.reviewHome.review-memory",
                "glimm.memoryDetail.review-memory"
            ]
        )
    }

    func testReviewCancellationOnlyIncludesReviewPrefixedReviewIdentifiers() {
        let identifiers = [
            NotificationDestination.reviewHome.makeReviewIdentifier(id: "candidate"),
            NotificationDestination.memoryDetail.makeReviewIdentifier(id: "candidate"),
            NotificationDestination.memoryDetail.makeIdentifier(id: "not-review"),
            NotificationDestination.capture.makeIdentifier(id: "review-capture")
        ]

        XCTAssertEqual(
            NotificationDestination.reviewIdentifiersToCancel(from: identifiers),
            [
                "glimm.reviewHome.review-candidate",
                "glimm.memoryDetail.review-candidate"
            ]
        )
    }

    func testHasReviewIdentifierOnlyMatchesReviewPrefixedReviewNotifications() {
        XCTAssertTrue(
            NotificationDestination.hasReviewIdentifier(
                in: [NotificationDestination.reviewHome.makeReviewIdentifier(id: "candidate")]
            )
        )

        XCTAssertFalse(
            NotificationDestination.hasReviewIdentifier(
                in: [
                    NotificationDestination.reviewHome.makeIdentifier(id: "not-review"),
                    NotificationDestination.capture.makeIdentifier(id: "review-capture")
                ]
            )
        )
    }

    private func makeTime(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
    }
}
