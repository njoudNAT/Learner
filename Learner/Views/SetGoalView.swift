import SwiftUI
import SwiftData

/// Pushed from Activity after a goal is completed or not met (Task 3).
/// Keep the same goal or choose a new one, then Start Learning.
struct SetGoalView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppClock.self) private var clock

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
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .background(Color(.systemBackground))
        .navigationTitle("Set a goal")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            BottomActionButton(
                title: "Start Learning",
                isEnabled: viewModel.canStart,
                isTyping: isFocused,
                action: start
            )
        }
        .sensoryFeedback(.success, trigger: viewModel.didStart)
        .sensoryFeedback(.selection, trigger: viewModel.duration)
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
