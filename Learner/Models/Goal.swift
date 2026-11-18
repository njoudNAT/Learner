//
//  Goal.swift
//  Learner
//
//  Created by Njoud Altalal on 30/05/1448 AH.
//
import Foundation
import SwiftData

nonisolated enum GoalStatus: String, Codable {
    case active
    case completed
    case failed
}

@Model
final class Goal {
    var title: String
    var duration: GoalDuration
    var startDate: Date
    var status: GoalStatus

    /// Set when a completed goal is reopened by an undo. The 32-hour window restarts from here,
    /// so the goal does not fail the moment it reopens. Optional, so existing data keeps working.
    var resumedAt: Date?

    // Entries stay when a goal ends, so the calendar keeps all history.
    @Relationship(deleteRule: .nullify, inverse: \DayEntry.goal)
    var entries: [DayEntry] = []

    init(title: String, duration: GoalDuration, startDate: Date = .now) {
        self.title = title
        self.duration = duration
        self.startDate = startDate
        self.status = .active
    }
}
