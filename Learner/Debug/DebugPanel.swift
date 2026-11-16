//
//  DebugPanel.swift
//  Learner
//
//  Created by Njoud Altalal on 05/06/1448 AH.
//
import SwiftUI
import SwiftData

// MARK: - Trigger (long-press; does nothing in release builds)

struct DebugPanelTrigger: ViewModifier {
    @State private var isShowing = false

    func body(content: Content) -> some View {
        #if DEBUG
        content
            .onLongPressGesture(minimumDuration: 1) { isShowing = true }
            .sheet(isPresented: $isShowing) {
                DebugPanelView()
                    .presentationDetents([.medium, .large])
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
        #else
        content
        #endif
    }
}

#if DEBUG

// MARK: - Panel

struct DebugPanelView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppClock.self) private var clock

    @Query(sort: \Goal.startDate, order: .reverse) private var goals: [Goal]
    @State private var pending: [String] = []

    /// Same rule as RootView: the running goal, otherwise the latest one.
    private var currentGoal: Goal? { goals.first { $0.status == .active } ?? goals.first }

    var body: some View {
        NavigationStack {
            List {
                Section("Play the week (no waiting)") {
                    if let goal = currentGoal {
                        Text("\(goal.title) · \(goal.duration.title) · \(goal.status.rawValue) · \(goal.learnedCount) learned, \(goal.frozenCount) freezed")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button("Log as Learned, then go to next day") {
                            WeekPlayer.logThenNextDay(goal, clock: clock, in: modelContext)
                        }
                        Button("Freeze, then go to next day") {
                            WeekPlayer.freezeThenNextDay(goal, clock: clock, in: modelContext)
                        }
                        .disabled(!goal.canFreeze(now: clock.now))   // same rule as the real button

                        if goal.status == .active && goal.freezesRemaining == 0 {
                            Text("No freezes left: only the Freeze button is off for the rest of this goal. Keep logging.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Button("Auto-play: I did the challenge") {
                            WeekPlayer.finishGoal(goal, clock: clock, in: modelContext)
                        }
                        Button("Auto-play: I missed it", role: .destructive) {
                            WeekPlayer.missGoal(goal, clock: clock)
                        }
                    } else {
                        Text("No goal yet. Load a scenario below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Time travel") {
                    Text("Pretend it is: \(clock.now.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundStyle(.secondary)
                    Text("Offset: \(Int(clock.debugOffset / 3600)) hours")
                        .foregroundStyle(.secondary)

                    Button("+1 hour") { clock.debugOffset += 3_600 }
                    Button("+1 day") { clock.debugOffset += 86_400 }
                    Button("+33 hours") { clock.debugOffset += 118_800 }
                    Button("Reset time", role: .destructive) { clock.debugOffset = 0 }
                }

                Section("Scenarios (replaces all data)") {
                    ForEach(DebugScenario.allCases) { scenario in
                        Button {
                            ScenarioSeeder.load(scenario, in: modelContext, clock: clock)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(scenario.title)
                                Text(scenario.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Notifications (background the app to see them)") {
                    Button("Send a test notification in 5 s") {
                        Task {
                            await NotificationService.shared.requestPermission()
                            await NotificationService.shared.sendTest()
                        }
                    }

                    Button("Show scheduled reminders") {
                        Task { pending = await NotificationService.shared.pendingSummary() }
                    }

                    ForEach(pending, id: \.self) { line in
                        Text(line).font(.caption)
                    }
                }
            }
            .navigationTitle("Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Scenarios

enum DebugScenario: String, CaseIterable, Identifiable {
    case freshInstall, dayOne, midWeek, loggedToday, frozenToday
    case noFreezesLeft, lastDayPending, completed, failed, longHistory
    case completedEarlier, monthGoal

    var id: Self { self }

    var title: String {
        switch self {
        case .freshInstall:   "Fresh install"
        case .dayOne:         "Day 1, nothing logged"
        case .midWeek:        "Mid-week"
        case .loggedToday:    "Logged today"
        case .frozenToday:    "Freezed today"
        case .noFreezesLeft:  "No freezes left"
        case .lastDayPending: "Last day pending"
        case .completed:      "Goal completed"
        case .failed:         "Goal not met"
        case .longHistory:    "Long history"
        case .completedEarlier: "Goal completed yesterday"
        case .monthGoal:      "Month goal"
        }
    }

    var detail: String {
        switch self {
        case .freshInstall:   "Empty app: shows Onboarding"
        case .dayOne:         "Week goal just started, both buttons active"
        case .midWeek:        "3 days of history, today open"
        case .loggedToday:    "Tap Logged as Learned to undo; Freeze is disabled"
        case .frozenToday:    "Tap Freezed for a day to undo; Log is disabled"
        case .noFreezesLeft:  "2 of 2 freezes used: Freeze disabled, Log active"
        case .lastDayPending: "Log today to complete the goal (then try the undo link)"
        case .completed:      "\"Well done!\" screen with Set a goal"
        case .failed:         "\"You didn’t reach your goal\" screen with Set a goal"
        case .longHistory:    "Two goals, 50 days of history in the calendar"
        case .completedEarlier: "\"Well done!\" with no undo link (it ended on an earlier day)"
        case .monthGoal:      "Month goal: 8 freezes, 30 days, 2 days logged"
        }
    }
}

@MainActor
enum ScenarioSeeder {

    static func load(_ scenario: DebugScenario, in context: ModelContext, clock: AppClock) {
        clock.debugOffset = 0
        clock.sync()

        try? context.delete(model: DayEntry.self)
        try? context.delete(model: Goal.self)

        let seed = SeedBuilder(context: context, now: clock.now)

        switch scenario {
        case .freshInstall:
            break

        case .dayOne:
            seed.goal(.week, startedDaysAgo: 0)

        case .midWeek:
            let goal = seed.goal(.week, startedDaysAgo: 3)
            seed.add(.learned, to: goal, daysAgo: 3)
            seed.add(.frozen, to: goal, daysAgo: 2)
            seed.add(.learned, to: goal, daysAgo: 1)

        case .loggedToday:
            let goal = seed.goal(.week, startedDaysAgo: 3)
            seed.add(.learned, to: goal, daysAgo: 3)
            seed.add(.frozen, to: goal, daysAgo: 2)
            seed.add(.learned, to: goal, daysAgo: 1)
            seed.add(.learned, to: goal, daysAgo: 0)

        case .frozenToday:
            let goal = seed.goal(.week, startedDaysAgo: 3)
            seed.add(.learned, to: goal, daysAgo: 3)
            seed.add(.frozen, to: goal, daysAgo: 2)
            seed.add(.learned, to: goal, daysAgo: 1)
            seed.add(.frozen, to: goal, daysAgo: 0)

        case .noFreezesLeft:
            let goal = seed.goal(.week, startedDaysAgo: 4)
            seed.add(.learned, to: goal, daysAgo: 4)
            seed.add(.frozen, to: goal, daysAgo: 3)
            seed.add(.frozen, to: goal, daysAgo: 2)
            seed.add(.learned, to: goal, daysAgo: 1)

        case .lastDayPending:
            let goal = seed.goal(.week, startedDaysAgo: 6)
            for daysAgo in [6, 5, 4, 2, 1] { seed.add(.learned, to: goal, daysAgo: daysAgo) }
            seed.add(.frozen, to: goal, daysAgo: 3)

        case .completed:
            let goal = seed.goal(.week, startedDaysAgo: 6, status: .completed)
            for daysAgo in [6, 5, 4, 2, 1, 0] { seed.add(.learned, to: goal, daysAgo: daysAgo) }
            seed.add(.frozen, to: goal, daysAgo: 3)

        case .failed:
            let goal = seed.goal(.week, startedDaysAgo: 4, status: .failed)
            seed.add(.learned, to: goal, daysAgo: 4)
            seed.add(.learned, to: goal, daysAgo: 3)
            seed.add(.frozen, to: goal, daysAgo: 2)

        case .completedEarlier:
            let goal = seed.goal(.week, startedDaysAgo: 7, status: .completed)
            for daysAgo in [7, 6, 5, 3, 2, 1] { seed.add(.learned, to: goal, daysAgo: daysAgo) }
            seed.add(.frozen, to: goal, daysAgo: 4)

        case .monthGoal:
            let goal = seed.goal(.month, startedDaysAgo: 2)
            seed.add(.learned, to: goal, daysAgo: 2)
            seed.add(.frozen, to: goal, daysAgo: 1)

        case .longHistory:
            let old = seed.goal(.month, startedDaysAgo: 50, status: .failed)
            for daysAgo in 21...50 {
                seed.add(daysAgo % 7 == 0 ? .frozen : .learned, to: old, daysAgo: daysAgo)
            }
            let current = seed.goal(.week, startedDaysAgo: 3)
            seed.add(.learned, to: current, daysAgo: 3)
            seed.add(.frozen, to: current, daysAgo: 2)
            seed.add(.learned, to: current, daysAgo: 1)
        }

        try? context.save()
    }
}

private struct SeedBuilder {
    let context: ModelContext
    let now: Date
    let calendar = Calendar.current

    /// A moment inside "n days ago", close enough to now that the 32-hour rule still holds.
    func stamp(daysAgo n: Int) -> Date {
        if n == 0 { return now }

        let target = calendar.date(byAdding: .day, value: -n, to: now) ?? now
        let dayStart = calendar.startOfDay(for: target)
        let secondsToday = now.timeIntervalSince(calendar.startOfDay(for: now))

        return dayStart.addingTimeInterval(max(60, secondsToday - 1_800))
    }

    @discardableResult
    func goal(
        _ duration: GoalDuration,
        startedDaysAgo n: Int,
        status: GoalStatus = .active,
        title: String = "Swift"
    ) -> Goal {
        let goal = Goal(title: title, duration: duration, startDate: stamp(daysAgo: n))
        goal.status = status
        context.insert(goal)
        return goal
    }

    func add(_ type: EntryType, to goal: Goal, daysAgo n: Int) {
        let entry = DayEntry(type: type, at: stamp(daysAgo: n))
        context.insert(entry)
        entry.goal = goal
    }
}


// MARK: - Play the week (moves the shared clock, so you never wait for a real day)

@MainActor
enum WeekPlayer {
    private static let day: TimeInterval = 86_400

    /// Taps "Log as Learned" for today (if allowed), then moves the clock to tomorrow.
    static func logThenNextDay(_ goal: Goal, clock: AppClock, in context: ModelContext) {
        clock.sync()
        if goal.canLog(now: clock.now) { goal.logLearned(now: clock.now, in: context) }
        advance(goal, clock: clock, by: day)
    }

    /// Taps "Freeze for a day" for today (if allowed), then moves the clock to tomorrow.
    /// If no freeze is possible and today is still empty, NOTHING happens and the clock
    /// does not move, exactly like the disabled Freeze button in the app.
    static func freezeThenNextDay(_ goal: Goal, clock: AppClock, in context: ModelContext) {
        clock.sync()
        let now = clock.now

        if goal.canFreeze(now: now) {
            goal.freezeToday(now: now, in: context)
        } else if goal.todayState(now: now) == .notLogged {
            return   // none left (or goal ended): don't skip a day by accident
        }

        advance(goal, clock: clock, by: day)
    }

    /// Does nothing today and moves on. Two skips in a row pass the 32-hour limit.
    static func skipDay(_ goal: Goal, clock: AppClock) {
        clock.sync()
        advance(goal, clock: clock, by: day)
    }

    /// Logs every remaining day, so the goal ends as "Well done!".
    static func finishGoal(_ goal: Goal, clock: AppClock, in context: ModelContext) {
        var steps = 0
        while goal.status == .active && steps <= goal.duration.totalDays {
            logThenNextDay(goal, clock: clock, in: context)
            steps += 1
        }
    }

    /// Does nothing for two days, so the goal ends as "not met".
    static func missGoal(_ goal: Goal, clock: AppClock) {
        clock.sync()
        advance(goal, clock: clock, by: 2 * day)
    }

    private static func advance(_ goal: Goal, clock: AppClock, by seconds: TimeInterval) {
        clock.debugOffset += seconds
        goal.refresh(now: clock.now)
    }
}

// MARK: - One preview per scenario (see every screen without running the app)

@MainActor
private func scenarioEnvironment(_ scenario: DebugScenario) -> (ModelContainer, AppClock) {
    let container = try! ModelContainer(
        for: Goal.self, DayEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let clock = AppClock()
    ScenarioSeeder.load(scenario, in: container.mainContext, clock: clock)
    return (container, clock)
}

@MainActor
private func scenarioRoot(_ scenario: DebugScenario) -> some View {
    let (container, clock) = scenarioEnvironment(scenario)

    return RootView()
        .modelContainer(container)
        .environment(clock)
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}

#Preview("Fresh install") { scenarioRoot(.freshInstall) }
#Preview("Day 1") { scenarioRoot(.dayOne) }
#Preview("Mid-week") { scenarioRoot(.midWeek) }
#Preview("Logged today") { scenarioRoot(.loggedToday) }
#Preview("Freezed today") { scenarioRoot(.frozenToday) }
#Preview("No freezes left") { scenarioRoot(.noFreezesLeft) }
#Preview("Last day pending") { scenarioRoot(.lastDayPending) }
#Preview("Completed") { scenarioRoot(.completed) }
#Preview("Not met") { scenarioRoot(.failed) }
#Preview("Completed yesterday") { scenarioRoot(.completedEarlier) }
#Preview("Month goal") { scenarioRoot(.monthGoal) }

#Preview("Calendar · long history") {
    let (container, clock) = scenarioEnvironment(.longHistory)

    return NavigationStack { CalendarView() }
        .modelContainer(container)
        .environment(clock)
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}

#Preview("Learning Goal · running goal") {
    let (container, clock) = scenarioEnvironment(.midWeek)
    let goal = try! container.mainContext.fetch(FetchDescriptor<Goal>()).first!

    return NavigationStack { GoalEditorView(goal: goal) }
        .modelContainer(container)
        .environment(clock)
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}

#Preview("Debug panel") {
    let (container, clock) = scenarioEnvironment(.midWeek)

    return DebugPanelView()
        .modelContainer(container)
        .environment(clock)
        .preferredColorScheme(.dark)
}

#endif
