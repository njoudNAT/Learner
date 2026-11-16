import Foundation
import Observation
import SwiftData

/// Where Activity can navigate to.
enum ActivityRoute: Hashable {
    case calendar
    case goalEditor    // change a RUNNING goal (shows the "streak will start over" alert)
    case setGoal       // start a new goal after one ended
}

@MainActor
@Observable
final class ActivityViewModel {

    let goal: Goal

    var path: [ActivityRoute] = []

    init(goal: Goal) {
        self.goal = goal
    }

    // MARK: - Display values (all derived from the goal's entries)

    var status: GoalStatus { goal.status }
    var learnedCount: Int { goal.learnedCount }
    var frozenCount: Int { goal.frozenCount }

    var freezeSummary: String {
        "\(goal.frozenCount) out of \(goal.duration.maxFreezes) Freezes used"
    }

    func todayState(now: Date) -> TodayState {
        goal.todayState(now: now)
    }

    func canLog(now: Date) -> Bool {
        goal.canLog(now: now)
    }

    func canFreeze(now: Date) -> Bool {
        goal.canFreeze(now: now)
    }

    /// Tappable = a new entry is allowed, or the same button can undo today's entry.
    func canTapLog(now: Date) -> Bool {
        goal.canLog(now: now) || goal.canUndo(.learned, now: now)
    }

    func canTapFreeze(now: Date) -> Bool {
        goal.canFreeze(now: now) || goal.canUndo(.frozen, now: now)
    }

    func canUndoToday(now: Date) -> Bool {
        goal.canUndo(.learned, now: now) || goal.canUndo(.frozen, now: now)
    }

    // MARK: - Actions

    func logLearned(clock: AppClock, in modelContext: ModelContext) {
        goal.logLearned(now: clock.now, in: modelContext)
        syncNotifications(clock: clock)
    }

    func freezeToday(clock: AppClock, in modelContext: ModelContext) {
        goal.freezeToday(now: clock.now, in: modelContext)
        syncNotifications(clock: clock)
    }

    func undoToday(clock: AppClock, in modelContext: ModelContext) {
        goal.undoToday(now: clock.now, in: modelContext)
        syncNotifications(clock: clock)
    }

    func refresh(clock: AppClock) {
        clock.sync()
        goal.refresh(now: clock.now)
        syncNotifications(clock: clock)
    }

    // MARK: - Navigation (one push at a time: a double tap can't stack two pages)

    func showCalendar() {
        push(.calendar)
    }

    /// The pencil button: edits a running goal, or sets a new one after the goal ended.
    func showGoalEditor() {
        push(goal.status == .active ? .goalEditor : .setGoal)
    }

    func showSetGoal() {
        push(.setGoal)
    }

    private func push(_ route: ActivityRoute) {
        guard path.isEmpty else { return }
        path.append(route)
    }

    // MARK: - Notifications

    private func syncNotifications(clock: AppClock) {
        // Notifications use the real clock, so skip while time-travelling and in previews.
        guard clock.debugOffset == 0 else { return }
        guard !ProcessInfo.processInfo.environment.keys.contains("XCODE_RUNNING_FOR_PREVIEWS") else { return }

        let goal = goal
        let now = clock.now

        Task { await NotificationService.shared.sync(goal: goal, now: now) }
    }

    // MARK: - Clock

    /// Re-checks the goal at midnight and at the 32-hour deadline,
    /// so the screen updates itself while the app stays open.
    func keepFresh(clock: AppClock) async {
        while !Task.isCancelled {
            clock.sync()
            goal.refresh(now: clock.now)
            syncNotifications(clock: clock)

            let wake = goal.nextRefreshDate(now: clock.now)
            let seconds = max(1, wake.timeIntervalSince(clock.now))

            try? await Task.sleep(for: .seconds(seconds))
        }
    }
}
