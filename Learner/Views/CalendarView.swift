import SwiftUI
import SwiftData

/// "Activities" (Task 5). View only: nothing on this screen can be tapped or edited.
struct CalendarView: View {
    @Environment(AppClock.self) private var clock

    // All history across every goal, so old days never disappear.
    @Query(sort: \DayEntry.day) private var entries: [DayEntry]

    @State private var position: Date?

    private let viewModel = CalendarViewModel()

    var body: some View {
        let now = clock.now
        let types = viewModel.typeByDay(entries: entries)
        let months = viewModel.monthStarts(now: now, entries: entries)

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
        .onAppear {
            // Opens on the current month.
            if position == nil {
                position = viewModel.startOfMonth(for: now)
            }
        }
    }
}

// MARK: - One month

private struct MonthSection: View {
    let month: Date
    let now: Date
    let types: [Date: EntryType]

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 0),
        count: 7
    )

    var body: some View {
        let calendar = Calendar.current
        let layout = MonthLayout(month: month)

        VStack(alignment: .leading, spacing: 12) {
            Text(month, format: .dateTime.month(.wide).year())
                .font(.headline)
                .padding(.horizontal, 20)
                .accessibilityAddTraits(.isHeader)

            // Weekday labels are repeated in every month, as in the Sketch.
            HStack(spacing: 0) {
                ForEach(Array(layout.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 4)
            .accessibilityHidden(true)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(0..<layout.leadingBlanks, id: \.self) { _ in
                    Color.clear.frame(height: 36)
                }

                ForEach(1...layout.dayCount, id: \.self) { number in
                    let day = layout.date(forDay: number)

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

    // The shared clock is set to the Sketch's "today".
    let clock = AppClock()
    clock.debugOffset = date(3, 12).timeIntervalSinceNow

    return NavigationStack { CalendarView() }
        .modelContainer(container)
        .environment(clock)
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}
