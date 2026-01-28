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
        "What's happening right now?",
        "Capture this moment!",
        "What are you up to?",
        "Time to save a memory",
        "What does your world look like?",
        "Pause and capture",
        "Document this moment",
        "What's around you?"
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

        let range = endMinutes - startMinutes
        var times: [Date] = []

        for _ in 0..<count {
            let randomMinutes = startMinutes + Int.random(in: 0..<range)
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
        content.body = messages.randomElement() ?? "What's happening right now?"
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
