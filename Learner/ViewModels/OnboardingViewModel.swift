//
//  OnboardingViewModel.swift
//  Learner
//
//  Created by Njoud Altalal on 01/06/1448 AH.
//


import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class OnboardingViewModel {
    var goalTitle = ""
    var duration: GoalDuration = .week
    var didStart = false

    var trimmedTitle: String {
        goalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canStart: Bool {
        !trimmedTitle.isEmpty
    }

    func startLearning(in modelContext: ModelContext) {
        guard canStart else { return }

        didStart.toggle()
        // RootView watches the goals list and swaps to the Activity page.
        modelContext.insert(Goal(title: trimmedTitle, duration: duration))
    }
}
