//
//  ActivityViewModel.swift
//  Learner
//
//  Created by Njoud Altalal on 01/06/1448 AH.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ActivityViewModel {
    var clock = Date.now
    var debugOffset: TimeInterval = 0

    var now: Date {
        clock.addingTimeInterval(debugOffset)
    }

    func todayState(for goal: Goal) -> TodayState {
        goal.todayState(now: now)
    }

    func canLog(goal: Goal) -> Bool {
        goal.canLog(now: now)
    }

    func canFreeze(goal: Goal) -> Bool {
        goal.canFreeze(now: now)
    }

    func logLearned(goal: Goal, in modelContext: ModelContext) {
        goal.logLearned(now: now, in: modelContext)
    }

    func freezeToday(goal: Goal, in modelContext: ModelContext) {
        goal.freezeToday(now: now, in: modelContext)
    }

    func refresh(goal: Goal) {
        clock = .now
        goal.refresh(now: now)
    }

    /// Re-checks the goal at midnight and at the 32-hour deadline.
    func runClock(goal: Goal) async {
        while !Task.isCancelled {
            clock = .now
            goal.refresh(now: now)

            let wake = goal.nextRefreshDate(now: now)
            let seconds = max(1, wake.timeIntervalSince(now))

            try? await Task.sleep(for: .seconds(seconds))
        }
    }
}

struct ClockKey: Hashable {
    let goalID: PersistentIdentifier
    let offset: TimeInterval
}
