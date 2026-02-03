//
//  CalendarView.swift
//  glimm
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Memory.capturedAt, order: .reverse) private var memories: [Memory]
    @State private var selectedDate = Date()
    @State private var selectedDayMemories: [Memory]?

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = [String(localized: "calendar.weekday.sun"), String(localized: "calendar.weekday.mon"), String(localized: "calendar.weekday.tue"), String(localized: "calendar.weekday.wed"), String(localized: "calendar.weekday.thu"), String(localized: "calendar.weekday.fri"), String(localized: "calendar.weekday.sat")]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthNavigator

                weekdayHeader

                calendarGrid

                Spacer()
            }
            .padding(.bottom, 100) // Space for tab bar
            .navigationTitle(String(localized: "calendar.title"))
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemBackground))
            .sheet(item: Binding(
                get: { selectedDayMemories.map { DayMemoriesWrapper(memories: $0, date: selectedDate) } },
                set: { selectedDayMemories = $0?.memories }
            )) { wrapper in
                DayMemoriesSheet(memories: wrapper.memories, date: wrapper.date)
            }
        }
    }

    private var monthNavigator: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }

            Spacer()

            Text(selectedDate, format: .dateTime.month(.wide).year())
                .font(.headline)

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(daysInMonth, id: \.self) { date in
                if let date = date {
                    dayCell(for: date)
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func dayCell(for date: Date) -> some View {
        let hasMemories = memoriesForDate(date).count > 0
        let isToday = calendar.isDateInToday(date)

        return Button {
            let dayMemories = memoriesForDate(date)
            if !dayMemories.isEmpty {
                selectedDate = date
                selectedDayMemories = dayMemories
            }
        } label: {
            ZStack {
                if isToday {
                    Circle()
                        .fill(colorScheme == .dark ? .white : .black)
                        .frame(width: 36, height: 36)
                }

                Text("\(calendar.component(.day, from: date))")
                    .font(.body)
                    .fontWeight(isToday ? .semibold : .regular)
                    .foregroundStyle(isToday ? (colorScheme == .dark ? .black : .white) : .primary)

                if hasMemories && !isToday {
                    Circle()
                        .fill(colorScheme == .dark ? .white : .black)
                        .frame(width: 6, height: 6)
                        .offset(y: 16)
                }
            }
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate) else {
            return []
        }

        let firstDayOfMonth = monthInterval.start
        let firstDayWeekday = calendar.component(.weekday, from: firstDayOfMonth)

        var days: [Date?] = []

        for _ in 1..<firstDayWeekday {
            days.append(nil)
        }

        var currentDate = firstDayOfMonth
        while currentDate < monthInterval.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return days
    }

    private func memoriesForDate(_ date: Date) -> [Memory] {
        memories.filter { memory in
            calendar.isDate(memory.capturedAt, inSameDayAs: date)
        }
    }

    private func moveMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: selectedDate) {
            selectedDate = newDate
        }
    }
}

// MARK: - Helper Types

struct DayMemoriesWrapper: Identifiable {
    let id = UUID()
    let memories: [Memory]
    let date: Date
}

struct DayMemoriesSheet: View {
    let memories: [Memory]
    let date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(memories) { memory in
                        MemoryCard(memory: memory)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemBackground))
            .navigationTitle(date.formatted(.dateTime.month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "calendar.done")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: Memory.self, inMemory: true)
}
