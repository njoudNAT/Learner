
import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = OnboardingViewModel()
    @FocusState private var isGoalFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                GoalFormFields(
                    title: $viewModel.goalTitle,
                    duration: $viewModel.duration,
                    isFocused: $isGoalFieldFocused
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .background(Color(.systemBackground))
        .safeAreaInset(edge: .bottom) { footer }
        .sensoryFeedback(.success, trigger: viewModel.didStart)
        .sensoryFeedback(.selection, trigger: viewModel.duration)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.brandOrange)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
                .accessibilityHidden(true)

            // "Hello" regular, "Learner" bold.
            Text("Hello \(Text("Learner").fontWeight(.bold))")
                .font(.largeTitle)

            Text("This app will help you learn everyday!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button(action: startLearning) {
                Text("Start Learning")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.brandOrange)
            .controlSize(.large)
            .disabled(!viewModel.canStart)

            Text("You can edit your desire later")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Actions

    private func startLearning() {
        guard viewModel.canStart else { return }
        isGoalFieldFocused = false
        viewModel.startLearning(in: modelContext)
    }
}

#Preview("Onboarding") {
    OnboardingView()
        .modelContainer(for: [Goal.self, DayEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}


