//
//  CalendarViewModel.swift
//  Learner
//
//  Created by Njoud Altalal on 01/06/1448 AH.
//

import Foundation

struct CalendarViewModel {
    private let monthsBack = 12
    private let monthsAhead = 24
    private let calendar = Calendar.current

    /// Start-of-day -> what happened. If two goals logged the same day, learned wins.
    func typeByDay(entries: [DayEntry]) -> [Date: EntryType] {
        var map: [Date: EntryType] = [:]

        for entry in entries {
            let day = calendar.startOfDay(for: entry.day)
            if map[day] == .learned { continue }
            map[day] = entry.type
        }

        return map
    }

    /// From 1 year back (or the first entry, if earlier) to 2 years ahead.
    func monthStarts(now: Date, entries: [DayEntry]) -> [Date] {
        let current = startOfMonth(for: now)
        let defaultStart = calendar.date(byAdding: .month, value: -monthsBack, to: current) ?? current
        let firstEntry = entries.first.map { startOfMonth(for: $0.day) } ?? defaultStart
        let start = min(firstEntry, defaultStart)
        let end = calendar.date(byAdding: .month, value: monthsAhead, to: current) ?? current

        var result: [Date] = []
        var cursor = start

        while cursor <= end {
            result.append(cursor)

            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }

        return result
    }

    func startOfMonth(for date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }
}

/// Grid math for one month.
struct MonthLayout {
    let month: Date
    private let calendar: Calendar

    init(month: Date, calendar: Calendar = .current) {
        self.month = month
        self.calendar = calendar
    }

    /// Empty cells before the 1st, based on the user's first weekday.
    var leadingBlanks: Int {
        (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
    }

    var dayCount: Int {
        calendar.range(of: .day, in: .month, for: month)?.count ?? 30
    }

    /// SUN MON TUE WED THU FRI SAT, starting at the user's first weekday.
    var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift]).map { $0.uppercased() }
    }

    func date(forDay number: Int) -> Date {
        calendar.date(byAdding: .day, value: number - 1, to: month) ?? month
    }
}
