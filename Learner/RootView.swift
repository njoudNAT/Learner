//
//  RootView.swift
//  Learner
//
//  Created by Njoud Altalal on 29/05/1448 AH.
//
import SwiftUI
import SwiftData

/// Decides which screen to show. No goal yet -> onboarding. Otherwise -> Activity.
/// Onboarding is never pushed, so there is no way to navigate "back" to it.
struct RootView: View {
    @Query(sort: \Goal.startDate, order: .reverse) private var goals: [Goal]

    var body: some View {
        ZStack {
            if let goal = goals.first {
                ActivityView(goal: goal)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: goals.isEmpty)
    }
}
