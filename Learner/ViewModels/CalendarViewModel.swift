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
        let current = startOfMonth(now)
        let defaultStart = calendar.date(
            byAdding: .month,
            value: -monthsBack,
            to: current
        ) ?? current

        let firstEntry = entries.first.map { startOfMonth($0.day) } ?? defaultStart
        let start = min(firstEntry, defaultStart)
        let end = calendar.date(
            byAdding: .month,
            value: monthsAhead,
            to: current
        ) ?? current

        var result: [Date] = []
        var cursor = start

        while cursor <= end {
            result.append(cursor)

            guard let next = calendar.date(
                byAdding: .month,
                value: 1,
                to: cursor
            ) else {
                break
            }

            cursor = next
        }

        return result
    }

    private func startOfMonth(_ date: Date) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }
}
