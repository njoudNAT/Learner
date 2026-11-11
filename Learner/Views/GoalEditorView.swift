
import SwiftUI
import SwiftData

/// "Learning Goal" page: pushed, native back chevron, ✓ on the right.
/// Also used for "Set a goal" after a goal is completed or not met.

struct GoalEditorView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: GoalEditorViewModel
    @FocusState private var isFocused: Bool

    init(goal: Goal, now: Date) {
        _viewModel = State(
            initialValue: GoalEditorViewModel(goal: goal, now: now)
        )
    }

    var body: some View {
        ScrollView {
            GoalFormFields(
                title: $viewModel.title,
                duration: $viewModel.duration,
                isFocused: $isFocused
            )
            .padding(.horizontal, 24)
            .padding(.top, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemBackground))
        .navigationTitle("Learning Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: confirmTapped) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.white)
                }
                .buttonStyle(.glassProminent)
                .tint(Color.brandOrange)
                .disabled(!viewModel.canConfirm)
                .accessibilityLabel("Save goal")
            }
        }
        .alert("Update goal", isPresented: $viewModel.showUpdateAlert) {
            Button("Dismiss", role: .cancel) { }
                .tint(.gray)

            Button("Update") {
                saveGoal()
            }
            .tint(Color.brandOrange)
        } message: {
            Text("If you update now, your streak will start over.")
        }
        .sensoryFeedback(.selection, trigger: viewModel.duration)
        .sensoryFeedback(.success, trigger: viewModel.didSave)
    }

    // MARK: - Actions

    private func confirmTapped() {
        isFocused = false

        if viewModel.goal.status == .active {
            viewModel.showUpdateAlert = true
        } else {
            saveGoal()
        }
    }

    private func saveGoal() {
        viewModel.saveGoal(in: modelContext)
        dismiss()
    }
}

#Preview("Goal Editor") {
    let container = try! ModelContainer(
        for: Goal.self, DayEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let goal = Goal(title: "Swift", duration: .week)
    container.mainContext.insert(goal)

    return NavigationStack {
        GoalEditorView(goal: goal, now: .now)
    }
    .modelContainer(container)
    .preferredColorScheme(.dark)
    .tint(Color.brandOrange)
}
