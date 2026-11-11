import SwiftUI
import SwiftData

/// "Learning Goal" page: pushed, native back chevron, ✓ on the right.
/// Also used for "Set a goal" after a goal is completed or not met.
struct GoalEditorView: View {
    let goal: Goal
    let now: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var duration: GoalDuration
    @State private var showUpdateAlert = false
    @State private var didSave = false
    @FocusState private var isFocused: Bool

    init(goal: Goal, now: Date) {
        self.goal = goal
        self.now = now
        _title = State(initialValue: goal.title)
        _duration = State(initialValue: goal.duration)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        trimmedTitle != goal.title || duration != goal.duration
    }

    /// While a goal runs, ✓ needs a real change. After it ended there is no
    /// streak to protect, so any non-empty goal is fine.
    private var canConfirm: Bool {
        !trimmedTitle.isEmpty && (goal.status != .active || hasChanges)
    }

    var body: some View {
        ScrollView {
            GoalFormFields(title: $title, duration: $duration, isFocused: $isFocused)
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
                }
                .buttonStyle(.glassProminent)
                .tint(Color.brandOrange)
                .disabled(!canConfirm)
                .accessibilityLabel("Save goal")
            }
        }
        .alert("Update goal", isPresented: $showUpdateAlert) {
            Button("Dismiss", role: .cancel) { }
            Button("Update") { saveGoal() }
        } message: {
            Text("If you update now, your streak will start over.")
        }
        .sensoryFeedback(.selection, trigger: duration)
        .sensoryFeedback(.success, trigger: didSave)
    }

    // MARK: - Actions

    private func confirmTapped() {
        isFocused = false
        if goal.status == .active {
            showUpdateAlert = true      // warn: the streak will reset
        } else {
            saveGoal()                  // nothing to lose
        }
    }

    private func saveGoal() {
        // The old goal ends, but its entries stay so the calendar keeps the history.
        if goal.status == .active { goal.status = .failed }

        // RootView shows the newest goal, so Activity switches to this one.
        modelContext.insert(Goal(title: trimmedTitle, duration: duration, startDate: now))
        didSave.toggle()
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

    return NavigationStack { GoalEditorView(goal: goal, now: .now) }
        .modelContainer(container)
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}
