//
//  SetGoalViewModel.swift
//  Learner
//
//  Created by Njoud Altalal on 05/06/1448 AH.
//
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SetGoalViewModel {
    let previous: Goal

    var title: String
    var duration: GoalDuration
    var didStart = false

    /// Pre-filled with the finished goal, so "same goal again" is one tap.
    init(previous: Goal) {
        self.previous = previous
        self.title = previous.title
        self.duration = previous.duration
    }

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canStart: Bool {
        !trimmedTitle.isEmpty
    }

    func start(now: Date, in modelContext: ModelContext) {
        guard canStart else { return }

        didStart.toggle()
        // The old goal already ended, so there is nothing to confirm.
        modelContext.insert(Goal(title: trimmedTitle, duration: duration, startDate: now))

        // Save right away so the new goal is permanent before RootView looks for the running goal.
        try? modelContext.save()

        #if DEBUG
        print("SetGoal started “\(trimmedTitle)” (\(duration.title)). Goals in database:",
              (try? modelContext.fetchCount(FetchDescriptor<Goal>())) ?? -1)
        #endif
    }
}
