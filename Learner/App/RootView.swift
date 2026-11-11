import SwiftUI
import SwiftData

/// No goal yet -> onboarding. Otherwise -> Activity.
/// Onboarding is never pushed, so there is no way to go "back" to it.
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

#Preview("Root") {
    RootView()
        .modelContainer(for: [Goal.self, DayEntry.self], inMemory: true)
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}
