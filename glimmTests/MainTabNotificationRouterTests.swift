import XCTest
@testable import glimm

final class MainTabNotificationRouterTests: XCTestCase {
    func testCaptureRoutePresentsCaptureWithoutChangingSelectedTab() {
        let target = MainTabNotificationRouter.target(
            for: NotificationRoute(destination: .capture),
            loadedMemoryIDs: []
        )

        XCTAssertEqual(
            target,
            MainTabNotificationRouteTarget(
                selectedTab: nil,
                presentsCapture: true,
                selectedMemoryID: nil
            )
        )
    }

    func testReviewHomeRouteSelectsReviewTab() {
        let target = MainTabNotificationRouter.target(
            for: NotificationRoute(destination: .reviewHome),
            loadedMemoryIDs: []
        )

        XCTAssertEqual(
            target,
            MainTabNotificationRouteTarget(
                selectedTab: .review,
                presentsCapture: false,
                selectedMemoryID: nil
            )
        )
    }

    func testLoadedMemoryDetailRouteSelectsReviewTabAndMemory() {
        let memoryID = UUID()
        let target = MainTabNotificationRouter.target(
            for: NotificationRoute(destination: .memoryDetail, memoryID: memoryID),
            loadedMemoryIDs: [memoryID]
        )

        XCTAssertEqual(
            target,
            MainTabNotificationRouteTarget(
                selectedTab: .review,
                presentsCapture: false,
                selectedMemoryID: memoryID
            )
        )
    }

    func testUnloadedMemoryDetailRouteOnlySelectsReviewTab() {
        let target = MainTabNotificationRouter.target(
            for: NotificationRoute(destination: .memoryDetail, memoryID: UUID()),
            loadedMemoryIDs: []
        )

        XCTAssertEqual(
            target,
            MainTabNotificationRouteTarget(
                selectedTab: .review,
                presentsCapture: false,
                selectedMemoryID: nil
            )
        )
    }
}
