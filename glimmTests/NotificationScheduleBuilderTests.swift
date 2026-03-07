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

    private func makeTime(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
    }
}
