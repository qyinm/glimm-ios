//
//  NotificationScheduleBuilder.swift
//  glimm
//

import Foundation

struct NotificationScheduleBuilder {
    static func scheduleDates(
        settings: Settings,
        now: Date = .now,
        calendar: Calendar = .current,
        randomMinute: (Range<Int>) -> Int = { Int.random(in: $0) }
    ) -> [Date] {
        guard settings.notifyEnabled else { return [] }

        return (0..<AppConstants.notificationScheduleDays)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: now) }
            .flatMap { day in
                dailyDates(
                    mode: settings.usesLegacyDailyCount ? nil : settings.cadenceMode,
                    dailyCount: settings.notifyFrequency,
                    intervalHours: settings.effectiveNotificationIntervalHours,
                    start: settings.notifyStart,
                    end: settings.notifyEnd,
                    for: day,
                    now: now,
                    calendar: calendar,
                    randomMinute: randomMinute
                )
            }
            .sorted()
    }

    static func dailyDates(
        mode: NotificationCadenceMode?,
        dailyCount: Int,
        intervalHours: Int,
        start: Date,
        end: Date,
        for day: Date,
        now: Date = .now,
        calendar: Calendar = .current,
        randomMinute: (Range<Int>) -> Int = { Int.random(in: $0) }
    ) -> [Date] {
        let ranges: [Range<Int>]

        switch mode {
        case .interval:
            ranges = intervalRanges(
                start: start,
                end: end,
                intervalHours: intervalHours,
                calendar: calendar
            )
        case .customCount, nil:
            ranges = countRanges(
                start: start,
                end: end,
                count: dailyCount,
                calendar: calendar
            )
        }

        return ranges.compactMap { range in
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            let minuteOfDay = randomMinute(range)
            components.hour = minuteOfDay / 60
            components.minute = minuteOfDay % 60
            return calendar.date(from: components)
        }
        .filter { $0 > now }
        .sorted()
    }

    static func intervalRanges(
        start: Date,
        end: Date,
        intervalHours: Int,
        calendar: Calendar = .current
    ) -> [Range<Int>] {
        let startMinutes = minutesInDay(from: start, calendar: calendar)
        let endMinutes = minutesInDay(from: end, calendar: calendar)
        let intervalMinutes = max(1, intervalHours) * 60

        guard endMinutes > startMinutes else { return [] }

        var ranges: [Range<Int>] = []
        var bucketStart = startMinutes

        while bucketStart < endMinutes {
            let bucketEnd = min(bucketStart + intervalMinutes, endMinutes)
            let segmentEnd = bucketEnd - AppConstants.notificationMinimumGapMinutes
            if segmentEnd > bucketStart {
                ranges.append(bucketStart..<segmentEnd)
            }
            bucketStart += intervalMinutes
        }

        return ranges
    }

    static func countRanges(
        start: Date,
        end: Date,
        count: Int,
        calendar: Calendar = .current
    ) -> [Range<Int>] {
        let startMinutes = minutesInDay(from: start, calendar: calendar)
        let endMinutes = minutesInDay(from: end, calendar: calendar)
        let safeCount = max(1, count)

        guard endMinutes > startMinutes else { return [] }

        let totalRange = endMinutes - startMinutes
        let segmentSize = max(1, totalRange / safeCount)

        return (0..<safeCount).compactMap { index in
            let segmentStart = startMinutes + (index * segmentSize)
            let rawEnd = min(segmentStart + segmentSize, endMinutes)
            let segmentEnd = rawEnd - AppConstants.notificationMinimumGapMinutes
            guard segmentEnd > segmentStart else { return nil }
            return segmentStart..<segmentEnd
        }
    }

    private static func minutesInDay(from date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}
