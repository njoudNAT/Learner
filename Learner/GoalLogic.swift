//
//  GoalLogic.swift
//  Learner
//
//  Created by Njoud Altalal on 30/05/1448 AH.
//
import Foundation
import SwiftData

/// What the user did today.
enum TodayState {
    case notLogged, learned, frozen
}

/// A streak survives at most 32 hours without a learned or frozen day.
private let streakWindow: TimeInterval = 32 * 60 * 60

// All rules live here, not in the views. Every function takes `now`,
// so we can test any day or time without waiting.
extension Goal {

    // MARK: - Derived values (never stored, so they can't get out of sync)

    var learnedCount: Int { entries.filter { $0.type == .learned }.count }
    var frozenCount: Int { entries.filter { $0.type == .frozen }.count }
    var freezesRemaining: Int { max(0, duration.maxFreezes - frozenCount) }

    func entry(on date: Date, calendar: Calendar = .current) -> DayEntry? {
        entries.first { calendar.isDate($0.day, inSameDayAs: date) }
    }

    func todayState(now: Date) -> TodayState {
        switch entry(on: now)?.type {
        case .learned: return .learned
        case .frozen:  return .frozen
        case nil:      return .notLogged
        }
    }

    // MARK: - What the buttons may do

    /// Logging stays possible after a freeze (the freeze becomes a learned day).
    func canLog(now: Date) -> Bool {
        status == .active && todayState(now: now) != .learned
    }

    /// Freezing needs: active goal, nothing logged today, freezes left.
    func canFreeze(now: Date) -> Bool {
        status == .active && todayState(now: now) == .notLogged && freezesRemaining > 0
    }

    // MARK: - Actions

    func logLearned(now: Date, in context: ModelContext) {
        guard canLog(now: now) else { return }
        if let existing = entry(on: now) {
            // Today was frozen: convert it. The freeze is refunded automatically
            // because freezesRemaining is derived from the entries.
            existing.type = .learned
            existing.loggedAt = now
        } else {
            insertEntry(.learned, now: now, in: context)
        }
        refresh(now: now)
    }

    func freezeToday(now: Date, in context: ModelContext) {
        guard canFreeze(now: now) else { return }
        insertEntry(.frozen, now: now, in: context)
        refresh(now: now)
    }

    private func insertEntry(_ type: EntryType, now: Date, in context: ModelContext) {
        let newEntry = DayEntry(type: type, goal: nil, at: now)
        context.insert(newEntry)
        newEntry.goal = self
        if !entries.contains(where: { $0 === newEntry }) {
            entries.append(newEntry)
        }
    }

    // MARK: - End-of-goal rules

    /// Call on launch, on returning to the foreground, and at each wake-up time.
    func refresh(now: Date) {
        guard status == .active else { return }

        // 1. Completed: every day of the goal is learned or frozen.
        if learnedCount + frozenCount >= duration.totalDays {
            status = .completed
            return
        }

        // 2. Failed: more than 32 hours without a learned or frozen day.
        let last = entries.map(\.loggedAt).max() ?? startDate
        if now.timeIntervalSince(last) > streakWindow {
            status = .failed
        }
    }

    /// The next moment something could change: midnight (buttons re-enable)
    /// or the 32-hour deadline, whichever comes first.
    func nextRefreshDate(now: Date, calendar: Calendar = .current) -> Date {
        let midnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)

        let last = entries.map(\.loggedAt).max() ?? startDate
        let deadline = last.addingTimeInterval(streakWindow)
        return deadline > now ? min(midnight, deadline) : midnight
    }
}
