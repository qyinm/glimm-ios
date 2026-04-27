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

    func testReviewScheduleDatesSkipDaysWithCaptureNotifications() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstDate = fixedDate(year: 2026, month: 4, day: 27, hour: 10)
        let occupiedDates = [
            fixedDate(year: 2026, month: 4, day: 27, hour: 9),
            fixedDate(year: 2026, month: 4, day: 29, hour: 18)
        ]

        let dates = NotificationScheduleBuilder.reviewScheduleDates(
            firstDate: firstDate,
            count: 3,
            occupiedDates: occupiedDates,
            calendar: calendar
        )

        XCTAssertEqual(dates, [
            fixedDate(year: 2026, month: 4, day: 28, hour: 10),
            fixedDate(year: 2026, month: 4, day: 30, hour: 10),
            fixedDate(year: 2026, month: 5, day: 1, hour: 10)
        ])
    }

    private func makeTime(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
    }

    private func fixedDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date!
    }
}
