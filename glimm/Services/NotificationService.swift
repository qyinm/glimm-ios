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

        guard settings.notifyEnabled else { return }

        let calendar = Calendar.current

        // Schedule for the next 7 days
        for dayOffset in 0..<7 {
            guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: Date()) else {
                continue
            }

            let randomTimes = generateRandomTimes(
                count: settings.notifyFrequency,
                start: settings.notifyStart,
                end: settings.notifyEnd,
                for: targetDate
            )

            for time in randomTimes {
                // Skip times in the past
                if time <= Date() { continue }

                await scheduleNotification(at: time)
            }
        }
    }

    /// Minimum gap between notifications in minutes
    private let minimumGapMinutes = AppConstants.notificationMinimumGapMinutes

    private func generateRandomTimes(
        count: Int,
        start: Date,
        end: Date,
        for date: Date
    ) -> [Date] {
        let calendar = Calendar.current

        let startHour = calendar.component(.hour, from: start)
        let startMinute = calendar.component(.minute, from: start)
        let endHour = calendar.component(.hour, from: end)
        let endMinute = calendar.component(.minute, from: end)

        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        guard endMinutes > startMinutes else { return [] }

        let totalRange = endMinutes - startMinutes
        var times: [Date] = []

        // Divide time range into segments to ensure minimum gap
        let segmentSize = totalRange / count

        for i in 0..<count {
            let segmentStart = startMinutes + (i * segmentSize)
            let segmentEnd = min(segmentStart + segmentSize - minimumGapMinutes, endMinutes)

            guard segmentEnd > segmentStart else { continue }

            let randomMinutes = Int.random(in: segmentStart..<segmentEnd)
            let hour = randomMinutes / 60
            let minute = randomMinutes % 60

            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = minute

            if let time = calendar.date(from: components) {
                times.append(time)
            }
        }

        return times.sorted()
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
