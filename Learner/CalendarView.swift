//
//  CalendarView.swift
//  Learner
//
//  Created by Njoud Altalal on 01/06/1448 AH.
//
import SwiftUI
import SwiftData

/// "Activities" (Task 5). View only: nothing on this screen can be tapped or edited.
/// "Activities" (Task 5). View only: nothing on this screen can be tapped or edited.
struct CalendarView: View {
    let now: Date

    // All history across every goal, so old days never disappear.
    @Query(sort: \DayEntry.day) private var entries: [DayEntry]

    /// How far the calendar reaches around today. Change these to taste.
    private let monthsBack = 12
    private let monthsAhead = 24

    @State private var position: Date?

    private let calendar = Calendar.current

    init(now: Date) {
        self.now = now
        let calendar = Calendar.current
        let current = calendar.dateInterval(of: .month, for: now)?.start
            ?? calendar.startOfDay(for: now)
        // Opens on the current month.
        _position = State<Date?>(initialValue: current)
    }

    var body: some View {
        let types = typeByDay
        let months = monthStarts

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(months.enumerated()), id: \.element) { index, month in
                    VStack(alignment: .leading, spacing: 0) {
                        if index > 0 { Divider() }   // line between months only
                        MonthSection(month: month, now: now, types: types)
                    }
                    .id(month)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $position, anchor: .top)
        .background(Color(.systemBackground))
        .navigationTitle("Activities")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Data

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

    /// From 1 year back (or the first entry, if earlier) to 2 years ahead.
    private var monthStarts: [Date] {
        let current = startOfMonth(now)
        let defaultStart = calendar.date(byAdding: .month, value: -monthsBack, to: current) ?? current
        let firstEntry = entries.first.map { startOfMonth($0.day) } ?? defaultStart
        let start = min(firstEntry, defaultStart)
        let end = calendar.date(byAdding: .month, value: monthsAhead, to: current) ?? current

        var result: [Date] = []
        var cursor = start
        while cursor <= end {
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
// MARK: - One month

private struct MonthSection: View {
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

    /// SUN MON TUE WED THU FRI SAT, starting at the user's first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift]).map { $0.uppercased() }
    }

    private func date(_ number: Int) -> Date {
        calendar.date(byAdding: .day, value: number - 1, to: month) ?? month
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(month, format: .dateTime.month(.wide).year())
                .font(.headline)
                .padding(.horizontal, 20)
                .accessibilityAddTraits(.isHeader)

            // Weekday labels are repeated in every month, as in the Sketch.
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
            .accessibilityHidden(true)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 36)
                }

                ForEach(1...dayCount, id: \.self) { number in
                    let day = date(number)
                    CalendarDay(
                        date: day,
                        isToday: calendar.isDate(day, inSameDayAs: now),
                        type: types[calendar.startOfDay(for: day)]
                    )
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.top, 18)
        .padding(.bottom, 16)
    }
}

// MARK: - One day (not tappable)

private struct CalendarDay: View {
    let date: Date
    let isToday: Bool
    let type: EntryType?

    var body: some View {
        Text(date, format: .dateTime.day())
            .font(.body.weight(isToday ? .semibold : .regular))
            .foregroundStyle(DayStyle.foreground(type, isToday: isToday))
            .frame(width: 36, height: 36)
            .background(DayStyle.background(type, isToday: isToday), in: Circle())
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(date.formatted(.dateTime.day().month(.wide)))\(stateWord)")
    }

    private var stateWord: String {
        switch type {
        case .learned: ", learned"
        case .frozen:  ", freezed"
        case nil:      isToday ? ", today" : ""
        }
    }
}

// MARK: - Preview (recreates the data in your Sketch: today is 12 March 2026)

#Preview("Calendar") {
    let container = try! ModelContainer(
        for: Goal.self, DayEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let calendar = Calendar.current
    let date = { (month: Int, day: Int) -> Date in
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12))!
    }

    let goal = Goal(title: "Swift", duration: .year, startDate: date(1, 1))
    container.mainContext.insert(goal)

    let add = { (month: Int, day: Int, type: EntryType) in
        let entry = DayEntry(type: type, at: date(month, day))
        container.mainContext.insert(entry)
        entry.goal = goal
    }

    for day in 1...11 { add(1, day, .learned) }
    for day in 1...28 where day != 20 && day != 23 { add(2, day, .learned) }
    for day in [1, 2, 4, 5, 6, 9, 10, 11] { add(3, day, .learned) }
    for (month, day) in [(2, 20), (2, 23), (3, 3), (3, 7), (3, 8)] { add(month, day, .frozen) }

    return NavigationStack { CalendarView(now: date(3, 12)) }
        .modelContainer(container)
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}
