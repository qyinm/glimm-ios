//
//  NotificationService.swift
//  glimm
//

import Foundation
import UserNotifications

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
        cancelAllNotifications()

        let dates = NotificationScheduleBuilder.scheduleDates(settings: settings, now: Date())
        for time in dates {
            await scheduleNotification(at: time)
        }
    }

    private func scheduleNotification(at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "glimm"
        content.body = messages.randomElement() ?? String(localized: "notification.message1")
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
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

    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }
}
