//
//  OnboardingView.swift
//  Learner
//
//  Created by Njoud Altalal on 29/05/1448 AH.
//
import SwiftUI
import SwiftData

/// Requires iOS 26 (Liquid Glass).
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var goalTitle = ""
    @State private var duration: GoalDuration = .week
    @State private var didStart = false
    @FocusState private var isGoalFieldFocused: Bool

    private var trimmedTitle: String {
        goalTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var canStart: Bool { !trimmedTitle.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                header
                goalField
                durationPicker
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .background(Color(.systemBackground))
        .safeAreaInset(edge: .bottom) { footer }
        .sensoryFeedback(.success, trigger: didStart)
        .sensoryFeedback(.selection, trigger: duration)
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

    private var goalField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("I want to learn")
                .font(.subheadline)

            TextField("Swift", text: $goalTitle)
                .focused($isGoalFieldFocused)
                .submitLabel(.done)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .onSubmit { isGoalFieldFocused = false }
                .onChange(of: goalTitle) { _, newValue in
                    if newValue.count > 40 { goalTitle = String(newValue.prefix(40)) }
                }

            Divider()
        }
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("I want to learn it in a")
                .font(.subheadline)

            // The container lets neighbouring glass shapes blend and animate together.
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(GoalDuration.allCases) { option in
                        DurationChip(title: option.title, isSelected: duration == option) {
                            withAnimation(.snappy) { duration = option }
                        }
                    }
                }
            }
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
            .disabled(!canStart)

            Text("You can edit your desire later")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Actions

    private func startLearning() {
        guard canStart else { return }
        isGoalFieldFocused = false
        didStart.toggle()
        // RootView watches the goals list and swaps to the Activity page.
        modelContext.insert(Goal(title: trimmedTitle, duration: duration))
    }
}

private struct DurationChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isSelected
                ? .regular.tint(Color.brandOrange).interactive()
                : .regular.interactive(),
            in: .capsule
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [Goal.self, DayEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}
