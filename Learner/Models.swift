//
//  Models.swift
//  Learner
//
//  Created by Njoud Altalal on 29/05/1448 AH.
//
import Foundation
import SwiftData

enum GoalDuration: String, CaseIterable, Codable, Identifiable {
    case week, month, year

    var id: Self { self }
    var title: String { rawValue.capitalized }          // "Week", "Month", "Year"

    /// Length of the goal in days.
    var totalDays: Int {
        switch self {
        case .week:  7
        case .month: 30
        case .year:  365
        }
    }

    /// Freezes allowed per goal (from the design spec).
    var maxFreezes: Int {
        switch self {
        case .week:  2
        case .month: 8
        case .year:  96
        }
    }
}

enum GoalStatus: String, Codable {
    case active, completed, failed
}

enum EntryType: String, Codable {
    case learned, frozen
}

@Model
final class Goal {
    var title: String
    var duration: GoalDuration
    var startDate: Date
    var status: GoalStatus

    // Entries are kept even when a goal ends, so the calendar shows all history.
    @Relationship(deleteRule: .nullify, inverse: \DayEntry.goal)
    var entries: [DayEntry] = []

    init(title: String, duration: GoalDuration) {
        self.title = title
        self.duration = duration
        self.startDate = .now
        self.status = .active
    }
}

@Model
final class DayEntry {
    var day: Date          // start of the calendar day (used by the calendar)
    var loggedAt: Date     // exact time (used by the 32-hour streak rule)
    var type: EntryType
    var goal: Goal?

    init(type: EntryType, goal: Goal?, at date: Date = .now) {
        self.type = type
        self.goal = goal
        self.loggedAt = date
        self.day = Calendar.current.startOfDay(for: date)
    }
}
