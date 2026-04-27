//
//  NotificationService.swift
//  glimm
//

import Foundation
import UserNotifications

struct NotificationRoute: Equatable {
    let destination: NotificationDestination
    let memoryID: UUID?

    init(destination: NotificationDestination, memoryID: UUID? = nil) {
        self.destination = destination
        self.memoryID = memoryID
    }

    init(userInfo: [AnyHashable: Any]) {
        let destination = NotificationDestination(userInfo: userInfo)
        self.init(
            destination: destination,
            memoryID: NotificationDestination.memoryID(from: userInfo)
        )
    }
}

enum NotificationDestination: String, CaseIterable {
    case capture
    case reviewHome
    case memoryDetail

    private static let identifierNamespace = "glimm"
    private static let kindUserInfoKey = "notificationKind"
    private static let memoryIDUserInfoKey = "memoryID"
    private static let reviewIdentifierSegment = "review"

    var userInfo: [AnyHashable: Any] {
        [Self.kindUserInfoKey: rawValue]
    }

    func userInfo(memoryID: UUID?) -> [AnyHashable: Any] {
        var payload = userInfo
        if let memoryID {
            payload[Self.memoryIDUserInfoKey] = memoryID.uuidString
        }
        return payload
    }

    init(userInfo: [AnyHashable: Any]) {
        guard
            let rawKind = userInfo[Self.kindUserInfoKey] as? String,
            let destination = Self(rawValue: rawKind)
        else {
            self = .capture
            return
        }

        self = destination
    }

    func makeIdentifier(id: String = UUID().uuidString) -> String {
        "\(Self.identifierNamespace).\(rawValue).\(id)"
    }

    func makeReviewIdentifier(id: String) -> String {
        makeIdentifier(id: "\(Self.reviewIdentifierSegment)-\(id)")
    }

    func matches(identifier: String) -> Bool {
        identifier.hasPrefix("\(Self.identifierNamespace).\(rawValue).")
    }

    func matchesReviewIdentifier(_ identifier: String) -> Bool {
        identifier.hasPrefix("\(Self.identifierNamespace).\(rawValue).\(Self.reviewIdentifierSegment)-")
    }

    static func identifiersToCancel(
        for destination: NotificationDestination,
        from identifiers: [String]
    ) -> [String] {
        identifiers.filter { identifier in
            if destination.matches(identifier: identifier) {
                return true
            }

            return destination == .capture && isLegacyIdentifier(identifier)
        }
    }

    static func reviewIdentifiersToCancel(from identifiers: [String]) -> [String] {
        identifiers.filter { identifier in
            NotificationDestination.reviewHome.matchesReviewIdentifier(identifier) ||
                NotificationDestination.memoryDetail.matchesReviewIdentifier(identifier)
        }
    }

    static func hasReviewIdentifier(in identifiers: [String]) -> Bool {
        !reviewIdentifiersToCancel(from: identifiers).isEmpty
    }

    static func memoryID(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard let rawID = userInfo[Self.memoryIDUserInfoKey] as? String else {
            return nil
        }

        return UUID(uuidString: rawID)
    }

    private static func isLegacyIdentifier(_ identifier: String) -> Bool {
        UUID(uuidString: identifier) != nil
    }
}

@MainActor
class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private let messages = [
        String(localized: "notification.message1"),
        String(localized: "notification.message2"),
        String(localized: "notification.message3"),
        String(localized: "notification.message4"),
        String(localized: "notification.message5"),
        String(localized: "notification.message6"),
        String(localized: "notification.message7"),
        String(localized: "notification.message8")
    ]

    private init() {}

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    func scheduleRandomNotifications(settings: Settings) async {
        await cancelNotifications(kind: .capture)

        let dates = NotificationScheduleBuilder.scheduleDates(settings: settings, now: Date())
        for time in dates {
            await scheduleNotification(at: time, destination: .capture)
        }
    }

    func scheduleReviewNotifications(
        candidates: [ReviewNotificationCandidate],
        firstDate: Date = Date().addingTimeInterval(60 * 60),
        forceRefresh: Bool = false
    ) async {
        if !forceRefresh {
            let hasPendingReviewNotifications = await hasPendingReviewNotifications()
            if hasPendingReviewNotifications {
                return
            }
        }

        await cancelReviewNotifications()

        let selectedCandidates = candidates.prefix(3)
        for (offset, candidate) in selectedCandidates.enumerated() {
            let date = Calendar.current.date(byAdding: .day, value: offset, to: firstDate) ?? firstDate
            await scheduleNotification(
                at: date,
                destination: candidate.destination,
                title: candidate.title,
                body: candidate.body,
                memoryID: candidate.memoryID,
                identifier: candidate.destination.makeReviewIdentifier(id: candidate.id)
            )
        }
    }

    private func scheduleNotification(
        at date: Date,
        destination: NotificationDestination,
        title: String = "glimm",
        body: String? = nil,
        memoryID: UUID? = nil,
        identifier: String? = nil
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body ?? messages.randomElement() ?? String(localized: "notification.message1")
        content.sound = .default
        content.userInfo = destination.userInfo(memoryID: memoryID)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: identifier ?? destination.makeIdentifier(),
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    func cancelNotifications(kind: NotificationDestination) async {
        let pendingIdentifiers = await center.pendingNotificationRequests().map(\.identifier)
        let identifiers = NotificationDestination.identifiersToCancel(
            for: kind,
            from: pendingIdentifiers
        )

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func cancelReviewNotifications() async {
        let pendingIdentifiers = await center.pendingNotificationRequests().map(\.identifier)
        let identifiers = NotificationDestination.reviewIdentifiersToCancel(from: pendingIdentifiers)

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func hasPendingReviewNotifications() async -> Bool {
        let pendingIdentifiers = await center.pendingNotificationRequests().map(\.identifier)
        return NotificationDestination.hasReviewIdentifier(in: pendingIdentifiers)
    }

    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }
}
