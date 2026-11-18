import SwiftUI
import SwiftData

/// "Learning Goal" page: pushed, native back chevron, ✓ on the right (always reachable,
/// even while typing), plus an "Update goal" button at the bottom when the keyboard is closed.
/// Only for changing a RUNNING goal. After a goal ends, Activity opens "Set a goal" instead.
struct GoalEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppClock.self) private var clock

    @State private var viewModel: GoalEditorViewModel
    @FocusState private var isFocused: Bool

    init(goal: Goal) {
        _viewModel = State(initialValue: GoalEditorViewModel(goal: goal))
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
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .background(Color(.systemBackground))
        .navigationTitle("Learning Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: confirmTapped) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.white)   // white ✓
                }
                .buttonStyle(.glassProminent)
                .tint(Color.brandOrange)
                .disabled(!viewModel.canConfirm || viewModel.showUpdateAlert)
                .accessibilityLabel("Save goal")
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionButton(
                title: "Update goal",
                isEnabled: viewModel.canConfirm && !viewModel.showUpdateAlert,
                isTyping: isFocused,
                action: confirmTapped
            )
        }
        // The alert is drawn last, so it covers the whole page, including the button.
        .overlay {
            if viewModel.showUpdateAlert {
                UpdateGoalAlert(
                    onDismiss: { viewModel.showUpdateAlert = false },
                    onUpdate: {
                        viewModel.showUpdateAlert = false
                        saveGoal()
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.25), value: viewModel.showUpdateAlert)
        .sensoryFeedback(.selection, trigger: viewModel.duration)
        .sensoryFeedback(.success, trigger: viewModel.didSave)
    }

    // MARK: - Actions

    private func confirmTapped() {
        isFocused = false   // the keyboard closes before the alert appears

        if viewModel.needsConfirmation {
            viewModel.showUpdateAlert = true
        } else {
            saveGoal()
        }
    }

    private func saveGoal() {
        viewModel.saveGoal(now: clock.now, in: modelContext)
        // RootView swaps to the new goal; dismiss is a safety net.
        dismiss()
    }
}

// MARK: - Alert from the Sketch (dark card, gray "Dismiss", orange "Update")

private struct UpdateGoalAlert: View {
    let onDismiss: () -> Void
    let onUpdate: () -> Void

    var body: some View {
        ZStack {
            // Dim layer. It also blocks touches on the page behind the alert.
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            card
                .padding(.horizontal, 40)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Update goal")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)

            Text("If you update now, your streak will start over.")
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                AlertButton(title: "Dismiss", fill: Color(.systemGray4), action: onDismiss)
                AlertButton(title: "Update", fill: Color.brandOrange, action: onUpdate)
            }
            .padding(.top, 16)
        }
        .padding(24)
        .frame(maxWidth: 340, alignment: .leading)
        .background(
            Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 34, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

private struct AlertButton: View {
    let title: String
    let fill: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(fill, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Goal Editor") {
    let container = try! ModelContainer(
        for: Goal.self, DayEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let goal = Goal(title: "Swift", duration: .week)
    container.mainContext.insert(goal)

    return NavigationStack {
        GoalEditorView(goal: goal)
    }
    .modelContainer(container)
    .environment(AppClock())
    .preferredColorScheme(.dark)
    .tint(Color.brandOrange)
}
