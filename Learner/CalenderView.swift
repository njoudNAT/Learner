//
//  CalenderView.swift
//  Learner
//
//  Created by Njoud Altalal on 30/05/1448 AH.
//
import SwiftUI
import SwiftData

/// "Activities" page: every learned and freezed day, month by month. View only.
struct CalendarView: View {
    let now: Date

    // All history, across every goal, so old days never disappear.
    @Query(sort: \DayEntry.day) private var entries: [DayEntry]

    private let calendar = Calendar.current

    var body: some View {
        let types = typeByDay
        let months = monthStarts

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(months, id: \.self) { month in
                        MonthView(month: month, now: now, types: types)
                            .id(month)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .onAppear {
                if let current = months.last {
                    proxy.scrollTo(current, anchor: .top)
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Activities")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Start-of-day -> what happened. If two goals logged the same day, learned wins.
    private var typeByDay: [Date: EntryType] {
        var map: [Date: EntryType] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.day)
            if map[day] == .learned { continue }
            map[day] = entry.type
        }
        return map
    }

    /// From the month of the first-ever entry up to the current month.
    private var monthStarts: [Date] {
        let currentMonth = startOfMonth(now)
        let firstMonth = entries.first.map { startOfMonth($0.day) } ?? currentMonth

        var result: [Date] = []
        var cursor = min(firstMonth, currentMonth)
        while cursor <= currentMonth {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    private func startOfMonth(_ date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}

private struct MonthView: View {
    let month: Date
    let now: Date
    let types: [Date: EntryType]

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    /// Empty cells before the 1st, based on the user's first weekday.
    private var leadingBlanks: Int {
        (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
    }

    private var dayCount: Int {
        calendar.range(of: .day, in: .month, for: month)?.count ?? 30
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(month, format: .dateTime.month(.wide).year())
                .font(.headline)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 34)
                }

                ForEach(1...dayCount, id: \.self) { number in
                    let date = calendar.date(byAdding: .day, value: number - 1, to: month) ?? month
                    DayBubble(
                        day: date,
                        isToday: calendar.isDate(date, inSameDayAs: now),
                        type: types[calendar.startOfDay(for: date)]
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Goal.self, DayEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let goal = Goal(title: "Swift", duration: .week)
    container.mainContext.insert(goal)
    for offset in 1...5 {
        let date = Calendar.current.date(byAdding: .day, value: -offset, to: .now)!
        let entry = DayEntry(type: offset == 3 ? .frozen : .learned, goal: nil, at: date)
        container.mainContext.insert(entry)
        entry.goal = goal
    }
    return NavigationStack { CalendarView(now: .now) }
        .modelContainer(container)
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}

