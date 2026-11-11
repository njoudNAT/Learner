//
//  DayEntry.swift
//  Learner
//
//  Created by Njoud Altalal on 30/05/1448 AH.
//
import Foundation
import SwiftData

nonisolated enum EntryType: String, Codable {
    case learned
    case frozen
}

@Model
final class DayEntry {
    var day: Date          // start of the calendar day (calendar)
    var loggedAt: Date     // exact time (32-hour rule)
    var type: EntryType
    var goal: Goal?

    init(type: EntryType, goal: Goal? = nil, at date: Date = .now) {
        self.day = Calendar.current.startOfDay(for: date)
        self.loggedAt = date
        self.type = type
        self.goal = goal
    }
}
