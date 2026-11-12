import SwiftUI
import SwiftData

/// No goal yet -> Onboarding. Otherwise -> Activity.
/// Onboarding is never pushed, so there is no way to go "back" to it.
struct RootView: View {
    @Query(sort: \Goal.startDate, order: .reverse) private var goals: [Goal]

    /// The running goal. If none is running, the most recent one (completed or failed).
    private var currentGoal: Goal? {
        goals.first { $0.status == .active } ?? goals.first
    }

    var body: some View {
        ZStack {
            if let goal = currentGoal {
                ActivityView(goal: goal)
                    .id(goal.persistentModelID)   // a new goal rebuilds the page fresh
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: currentGoal?.persistentModelID)
    }
}

#Preview("Root") {
    RootView()
        .modelContainer(for: [Goal.self, DayEntry.self], inMemory: true)
        .environment(AppClock())
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}
