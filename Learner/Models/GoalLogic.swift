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

    func entry(on date: Date, calendar: Calendar = .current) -> DayEntry? {
        entries.first { calendar.isDate($0.day, inSameDayAs: date) }
    }

    func todayState(now: Date = .now) -> TodayState {
        switch entry(on: now)?.type {
        case .learned: return .learned
        case .frozen:  return .frozen
        case nil:      return .notLogged
        }
    }

    // MARK: - Button rules

    /// Logging stays possible after a freeze (the freeze becomes a learned day).
    func canLog(now: Date = .now) -> Bool {
        status == .active && todayState(now: now) != .learned
    }

    func canFreeze(now: Date = .now) -> Bool {
        status == .active && todayState(now: now) == .notLogged && freezesRemaining > 0
    }

    // MARK: - Actions

    func logLearned(now: Date = .now, in context: ModelContext) {
        guard canLog(now: now) else { return }

        if let existing = entry(on: now) {
            // Today was frozen: convert it. The freeze is refunded automatically,
            // because freezesRemaining is derived from the entries.
            existing.type = .learned
            existing.loggedAt = now
        } else {
            addEntry(.learned, now: now, in: context)
        }
        refresh(now: now)
    }

    func freezeToday(now: Date = .now, in context: ModelContext) {
        guard canFreeze(now: now) else { return }
        addEntry(.frozen, now: now, in: context)
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
        let last = entries.map(\.loggedAt).max() ?? startDate
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

        let last = entries.map(\.loggedAt).max() ?? startDate
        let deadline = last.addingTimeInterval(Rules.streakWindow)
        return deadline > now ? min(midnight, deadline) : midnight
    }
}
