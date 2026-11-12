//
//  GoalEditorViewModel.swift
//  Learner
//
//  Created by Njoud Altalal on 01/06/1448 AH.
//
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class GoalEditorViewModel {
    let goal: Goal

    var title: String
    var duration: GoalDuration
    var showUpdateAlert = false
    var didSave = false

    init(goal: Goal) {
        self.goal = goal
        self.title = goal.title
        self.duration = goal.duration
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasChanges: Bool {
        trimmedTitle != goal.title || duration != goal.duration
    }

    /// While a goal runs, ✓ needs a real change. After it ended there is no
    /// streak to protect, so any non-empty goal is fine.
    var canConfirm: Bool {
        !trimmedTitle.isEmpty && (goal.status != .active || hasChanges)
    }

    /// Saving a running goal ends its streak, so the user must confirm first.
    var needsConfirmation: Bool {
        goal.status == .active
    }

    func saveGoal(now: Date, in modelContext: ModelContext) {
        // The old goal ends, but its entries stay so the calendar keeps the history.
        if goal.status == .active {
            goal.status = .failed
        }

        // RootView shows the running goal, so Activity switches to this one.
        modelContext.insert(Goal(title: trimmedTitle, duration: duration, startDate: now))
        didSave.toggle()
    }
}
