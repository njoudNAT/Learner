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
                ActivityPlaceholder(goal: goal)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: goals.isEmpty)
    }
}

/// Temporary. We replace this with the real Activity page next.
private struct ActivityPlaceholder: View {
    let goal: Goal

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("Learning \(goal.title)")
                    .font(.title2.bold())
                Text("in a \(goal.duration.title.lowercased())")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Activity")
        }
    }
}
