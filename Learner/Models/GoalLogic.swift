import Foundation
import SwiftData

nonisolated enum TodayState: Equatable {
    case notLogged
    case learned
    case frozen
}

private enum Rules {

    /// A streak survives at most 32 hours without a learned or frozen day.
    static let streakWindow: TimeInterval = 32 * 60 * 60

}

extension Goal {

    // MARK: - Derived values (never stored, so they can't get out of sync)

    var learnedCount: Int { entries.filter { $0.type == .learned }.count }

    var frozenCount: Int { entries.filter { $0.type == .frozen }.count }

    var freezesRemaining: Int { max(0, duration.maxFreezes - frozenCount) }

    /// The moment the 32-hour window counts from: the last entry (or the goal's start),
    /// or the moment the goal was last reopened by an undo, whichever is later.
    func lastActivityDate(excluding excluded: DayEntry? = nil) -> Date {
        let lastEntry = entries
            .filter { $0 !== excluded }
            .map(\.loggedAt)
            .max() ?? startDate

        return max(lastEntry, resumedAt ?? .distantPast)
    }

    func entry(on date: Date, calendar: Calendar = .current) -> DayEntry? {
        entries.first { calendar.isDate($0.day, inSameDayAs: date) }
    }

    func todayState(now: Date = .now) -> TodayState {
        switch entry(on: now)?.type {
        case .learned: return .learned
        case .frozen: return .frozen
        case nil: return .notLogged
        }
    }

    // MARK: - Button rules

    /// One entry per day. After a day is logged or freezed, the OTHER button is
    /// disabled until midnight. Pressing the SAME button again undoes the entry.

    func canLog(now: Date = .now) -> Bool {
        status == .active && todayState(now: now) == .notLogged
    }

    func canFreeze(now: Date = .now) -> Bool {
        status == .active && todayState(now: now) == .notLogged && freezesRemaining > 0
    }

    /// Undo works while the goal runs, and on the day it was completed
    /// (a mis-tap on the last day can be reversed). A failed goal can never be undone,
    /// and an undo may not push the goal past its 32-hour deadline.
    func canUndo(_ type: EntryType, now: Date = .now) -> Bool {
        guard status == .active || status == .completed,
              let todayEntry = entry(on: now),
              todayEntry.type == type else { return false }

        let previous = lastActivityDate(excluding: todayEntry)

        return now.timeIntervalSince(previous) <= Rules.streakWindow
    }

    // MARK: - Actions

    func logLearned(now: Date = .now, in context: ModelContext) {
        // Pressing the same button again undoes today's entry.
        if canUndo(.learned, now: now) {
            removeTodayEntry(now: now, in: context)
            return
        }

        guard canLog(now: now) else { return }

        addEntry(.learned, now: now, in: context)
        refresh(now: now)
    }

    func freezeToday(now: Date = .now, in context: ModelContext) {
        // Pressing the same button again undoes today's freeze.
        if canUndo(.frozen, now: now) {
            removeTodayEntry(now: now, in: context)
            return
        }

        guard canFreeze(now: now) else { return }

        addEntry(.frozen, now: now, in: context)
        refresh(now: now)
    }

    /// The Well done page can always undo the entry that completed the goal, on any later day.
    var canUndoCompletion: Bool {
        status == .completed && !entries.isEmpty
    }

    /// Removes the entry that completed the goal and reopens it. The 32-hour window restarts
    /// from now, so a late undo reopens the goal instead of failing it.
    func undoCompletion(now: Date = .now, in context: ModelContext) {
        guard canUndoCompletion,
              let last = entries.max(by: { $0.loggedAt < $1.loggedAt }) else { return }

        entries.removeAll { $0 === last }
        last.goal = nil
        context.delete(last)

        status = .active
        resumedAt = now
        refresh(now: now)
    }

    /// Undo from outside the two buttons.
    func undoToday(now: Date = .now, in context: ModelContext) {
        guard let type = entry(on: now)?.type, canUndo(type, now: now) else { return }
        removeTodayEntry(now: now, in: context)
    }

    private func removeTodayEntry(now: Date, in context: ModelContext) {
        guard let todayEntry = entry(on: now) else { return }

        entries.removeAll { $0 === todayEntry }
        todayEntry.goal = nil
        context.delete(todayEntry)

        // Undoing the last day reopens a goal that was just completed.
        if status == .completed { status = .active }
        refresh(now: now)
    }

    private func addEntry(_ type: EntryType, now: Date, in context: ModelContext) {

        let newEntry = DayEntry(type: type, at: now)

        context.insert(newEntry)          // insert first, then link
        newEntry.goal = self

        if !entries.contains(where: { $0 === newEntry }) {
            entries.append(newEntry)
        }
    }

    // MARK: - End-of-goal rules

    func refresh(now: Date = .now) {

        guard status == .active else { return }

        // Completed: every day of the goal is learned or frozen.
        if learnedCount + frozenCount >= duration.totalDays {
            status = .completed
            return
        }

        // Failed: more than 32 hours without a learned or frozen day.
        let last = lastActivityDate()

        if now.timeIntervalSince(last) > Rules.streakWindow {
            status = .failed
        }
    }

    /// Next moment something can change: midnight or the 32-hour deadline.
    func nextRefreshDate(now: Date = .now, calendar: Calendar = .current) -> Date {

        let midnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(3600)

        let last = lastActivityDate()
        let deadline = last.addingTimeInterval(Rules.streakWindow)

        return deadline > now ? min(midnight, deadline) : midnight
    }

}
