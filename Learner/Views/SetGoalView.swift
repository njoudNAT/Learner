//
//  SetGoalView.swift
//  Learner
//
//  Created by Njoud Altalal on 05/06/1448 AH.
//

import SwiftUI
import SwiftData

/// Pushed from Activity after a goal is completed or not met (Task 3).
/// Keep the same goal or choose a new one, then Start Learning.
struct SetGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppClock.self) private var clock
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: SetGoalViewModel
    @FocusState private var isFocused: Bool

    init(previous: Goal) {
        _viewModel = State(initialValue: SetGoalViewModel(previous: previous))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Keep the same goal or choose a new one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                GoalFormFields(
                    title: $viewModel.title,
                    duration: $viewModel.duration,
                    isFocused: $isFocused
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemBackground))
        .navigationTitle("Set a goal")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { footer }
        .sensoryFeedback(.success, trigger: viewModel.didStart)
        .sensoryFeedback(.selection, trigger: viewModel.duration)
    }

    private var footer: some View {
        Button(action: start) {
            Text("Start Learning")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(Color.brandOrange)
        .controlSize(.large)
        .disabled(!viewModel.canStart)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func start() {
        isFocused = false
        viewModel.start(now: clock.now, in: modelContext)
        // RootView now shows the new running goal. dismiss() is a safety net,
        // so this page never stays open after Start Learning.
        dismiss()
        Task { await NotificationService.shared.requestPermission() }
    }
}

#Preview("Set a goal") {
    let container = try! ModelContainer(
        for: Goal.self, DayEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let goal = Goal(title: "Swift", duration: .week)
    goal.status = .completed
    container.mainContext.insert(goal)

    return NavigationStack { SetGoalView(previous: goal) }
        .modelContainer(container)
        .environment(AppClock())
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}
