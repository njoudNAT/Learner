
import SwiftUI
import SwiftData

/// Activities screen. View only: nothing can be tapped or edited.
struct CalendarView: View {
    let now: Date

    @Query(sort: \DayEntry.day) private var entries: [DayEntry]

    @State private var position: Date?

    private let viewModel = CalendarViewModel()

    init(now: Date) {
        self.now = now

        let calendar = Calendar.current
        let current = calendar.dateInterval(of: .month, for: now)?.start
            ?? calendar.startOfDay(for: now)

        _position = State<Date?>(initialValue: current)
    }

    var body: some View {
        let types = viewModel.typeByDay(from: entries)
        let months = viewModel.monthStarts(from: entries, now: now)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(months.enumerated()), id: \.element) { index, month in
                    VStack(alignment: .leading, spacing: 0) {
                        if index > 0 {
                            Divider()
                        }

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
}

// MARK: - One month

private struct MonthSection: View {
    let month: Date
    let now: Date
    let types: [Date: EntryType]

    private let calendar = Calendar.current
    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 0),
        count: 7
    )

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
            .map { $0.uppercased() }
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

// MARK: - One day

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
            .accessibilityLabel(
                "\(date.formatted(.dateTime.day().month(.wide)))\(stateWord)"
            )
    }

    private var stateWord: String {
        switch type {
        case .learned: ", learned"
        case .frozen: ", freezed"
        case nil: isToday ? ", today" : ""
        }
    }
}

// MARK: - Preview

#Preview("Calendar") {
    let container = try! ModelContainer(
        for: Goal.self, DayEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let calendar = Calendar.current

    let date = { (month: Int, day: Int) -> Date in
        calendar.date(
            from: DateComponents(year: 2026, month: month, day: day, hour: 12)
        )!
    }

    let goal = Goal(title: "Swift", duration: .year, startDate: date(1, 1))
    container.mainContext.insert(goal)

    let add = { (month: Int, day: Int, type: EntryType) in
        let entry = DayEntry(type: type, at: date(month, day))
        container.mainContext.insert(entry)
        entry.goal = goal
    }

    for day in 1...11 {
        add(1, day, .learned)
    }

    for day in 1...28 where day != 20 && day != 23 {
        add(2, day, .learned)
    }

    for day in [1, 2, 4, 5, 6, 9, 10, 11] {
        add(3, day, .learned)
    }

    for (month, day) in [(2, 20), (2, 23), (3, 3), (3, 7), (3, 8)] {
        add(month, day, .frozen)
    }

    return NavigationStack {
        CalendarView(now: date(3, 12))
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
    .tint(Color.brandOrange)
}

