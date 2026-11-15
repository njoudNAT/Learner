
import Foundation
import Observation
import SwiftData

/// Where Activity can navigate to.
enum ActivityRoute: Hashable {
    case calendar
    case goalEditor
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

    // MARK: - Actions

    func logLearned(now: Date, in modelContext: ModelContext) {
        goal.logLearned(now: now, in: modelContext)
    }

    func freezeToday(now: Date, in modelContext: ModelContext) {
        goal.freezeToday(now: now, in: modelContext)
    }

    func refresh(clock: AppClock) {
        clock.sync()
        goal.refresh(now: clock.now)
    }

    // MARK: - Navigation

    func showCalendar() {
        path.append(.calendar)
    }

    func showGoalEditor() {
        path.append(.goalEditor)
    }

    // MARK: - Clock

    /// Re-checks the goal at midnight and at the 32-hour deadline,
    /// so the screen updates itself while the app stays open.
    func keepFresh(clock: AppClock) async {

        while !Task.isCancelled {

            clock.sync()
            goal.refresh(now: clock.now)

            let wake = goal.nextRefreshDate(now: clock.now)
            let seconds = max(1, wake.timeIntervalSince(clock.now))

            try? await Task.sleep(for: .seconds(seconds))
        }
    }

}
