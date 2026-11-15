
import SwiftUI
import SwiftData

struct ActivityView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppClock.self) private var clock

    @State private var viewModel: ActivityViewModel

    init(goal: Goal) {
        _viewModel = State(initialValue: ActivityViewModel(goal: goal))
    }

    private var goal: Goal { viewModel.goal }

    private var now: Date { clock.now }

    private var todayState: TodayState { viewModel.todayState(now: now) }

    private var hasDailyAction: Bool {
        todayState != .notLogged
    }

    var body: some View {

        NavigationStack(path: $viewModel.path) {

            ScrollView {

                VStack(spacing: 28) {

                    header

                    WeekStrip(goal: goal, now: now)
                        .modifier(DebugTimeTravel())

                    statCards

                    stateContent
                }

                .padding(.horizontal, 20)
                .padding(.top, 8)
                .animation(.smooth, value: todayState)
                .animation(.smooth, value: viewModel.status)
            }

            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom) { freezeFooter }

            .navigationDestination(for: ActivityRoute.self) { route in

                switch route {

                case .calendar:
                    CalendarView()

                case .goalEditor:
                    GoalEditorView(goal: goal)
                }
            }
        }

        .task(id: clock.debugOffset) {
            await viewModel.keepFresh(clock: clock)
        }

        .onChange(of: scenePhase) { _, phase in

            if phase == .active {
                viewModel.refresh(clock: clock)
            }
        }

        .sensoryFeedback(.success, trigger: viewModel.learnedCount)
        .sensoryFeedback(.impact, trigger: viewModel.frozenCount)
    }

    // MARK: - Sections

    private var header: some View {

        HStack(alignment: .top, spacing: 12) {

            VStack(alignment: .leading, spacing: 2) {

                Text("Activity")
                    .font(.largeTitle.bold())

                Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            GlassEffectContainer(spacing: 12) {

                HStack(spacing: 12) {

                    HeaderButton(symbol: "calendar", label: "Calendar") {
                        viewModel.showCalendar()
                    }

                    HeaderButton(symbol: "pencil.and.outline", label: "Edit learning goal") {
                        viewModel.showGoalEditor()
                    }
                }
            }
        }
    }

    private var statCards: some View {

        GlassEffectContainer(spacing: 12) {

            HStack(spacing: 12) {

                StatCard(
                    symbol: "flame.fill",
                    tint: Color.brandOrange,
                    count: viewModel.learnedCount,
                    caption: "Learned"
                )

                StatCard(
                    symbol: "snowflake",
                    tint: Color.brandFreezeBlue,
                    count: viewModel.frozenCount,
                    caption: "Freezed"
                )
            }
        }
    }

    @ViewBuilder
    private var stateContent: some View {

        switch viewModel.status {

        case .active:
            logButton

        case .completed:

            VStack(spacing: 20) {

                EndState(
                    symbol: "hands.clap.fill",
                    title: "Well done!",
                    message: "Ready for your next goal?",
                    onSetGoal: viewModel.showGoalEditor
                )

                if todayState == .learned {
                    logButton
                }
            }

        case .failed:
            EndState(
                symbol: "xmark.seal.fill",
                title: "You didn’t reach your goal this time.",
                message: "Want to set another goal?",
                onSetGoal: viewModel.showGoalEditor
            )
        }
    }

    private var logButton: some View {

        let isLogged = todayState == .learned

        let canTap = viewModel.canLog(now: now) || isLogged

        return Button {

            viewModel.logLearned(now: now, in: modelContext)

        } label: {

            Text(isLogged ? "Logged as Learned" : "Log as Learned")
                .font(.title3.weight(.semibold))
                .foregroundStyle(hasDailyAction ? Color.secondary : Color.white)
                .frame(width: 240, height: 240)
        }

        .buttonStyle(.plain)

        .glassEffect(
            hasDailyAction
                ? .regular.interactive()
                : .regular.tint(Color.brandOrange).interactive(),
            in: .circle
        )

        .disabled(!canTap)
        .padding(.top, 24)
    }

    @ViewBuilder
    private var freezeFooter: some View {

        if viewModel.status == .active || todayState == .frozen {

            VStack(spacing: 8) {

                Button {

                    viewModel.freezeToday(now: now, in: modelContext)

                } label: {

                    Text(todayState == .frozen ? "Freezed for a day" : "Freeze for a day")
                        .font(.headline)
                        .foregroundStyle(hasDailyAction ? Color.secondary : Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }

                .buttonStyle(.glassProminent)

                .tint(
                    hasDailyAction
                        ? Color.gray
                        : Color.brandFreezeBlue
                )

                .controlSize(.large)

                .disabled(
                    !viewModel.canFreeze(now: now) &&
                    todayState != .frozen
                )

                Text(viewModel.freezeSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Header button (44pt, Apple's minimum tap size)

private struct HeaderButton: View {

    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {

        Button(action: action) {

            Image(systemName: symbol)
                .font(.title3.weight(.medium))
                .frame(width: 44, height: 44)
        }

        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(label)
    }
}

// MARK: - Week strip (S M T W T F S, the current week)

private struct WeekStrip: View {

    let goal: Goal
    let now: Date

    private var days: [Date] {

        let calendar = Calendar.current

        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return []
        }

        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: week.start)
        }
    }

    var body: some View {

        HStack(spacing: 0) {

            ForEach(days, id: \.self) { day in

                VStack(spacing: 8) {

                    Text(day, format: .dateTime.weekday(.narrow))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    DayBubble(
                        day: day,
                        isToday: Calendar.current.isDate(day, inSameDayAs: now),
                        type: goal.entry(on: day)?.type
                    )
                }

                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Stat card and end state

private struct StatCard: View {

    let symbol: String
    let tint: Color
    let count: Int
    let caption: String

    var body: some View {

        VStack(spacing: 4) {

            Image(systemName: symbol)
                .foregroundStyle(tint)

            Text(count == 1 ? "1 day" : "\(count) days")
                .font(.headline)
                .contentTransition(.numericText())

            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .animation(.snappy, value: count)
        .accessibilityElement(children: .combine)
    }
}

private struct EndState: View {

    let symbol: String
    let title: String
    let message: String
    let onSetGoal: () -> Void

    var body: some View {

        VStack(spacing: 12) {

            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(Color.brandOrange)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: onSetGoal) {

                Label("Set a goal", systemImage: "pencil.circle")
                    .font(.headline)
            }

            .buttonStyle(.glassProminent)
            .tint(Color.brandOrange)
            .controlSize(.large)
            .padding(.top, 8)
        }

        .padding(.top, 40)
    }
}

// MARK: - Debug time travel (long-press the week strip; does nothing in release)

private struct DebugTimeTravel: ViewModifier {

    @Environment(AppClock.self) private var clock
    @State private var isShowing = false

    func body(content: Content) -> some View {

        #if DEBUG

        content
            .onLongPressGesture(minimumDuration: 1) {
                isShowing = true
            }

            .confirmationDialog("Time travel (debug only)", isPresented: $isShowing) {

                Button("+1 hour") { clock.debugOffset += 3_600 }
                Button("+1 day") { clock.debugOffset += 86_400 }
                Button("+33 hours") { clock.debugOffset += 118_800 }
                Button("Reset time", role: .destructive) { clock.debugOffset = 0 }
            }

        #else

        content

        #endif
    }
}

// MARK: - Preview

#Preview("Activity") {

    let container = try! ModelContainer(
        for: Goal.self, DayEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let calendar = Calendar.current

    let start = calendar.date(byAdding: .day, value: -3, to: .now)!

    let goal = Goal(title: "Swift", duration: .week, startDate: start)

    container.mainContext.insert(goal)

    for offset in 1...3 {

        let date = calendar.date(byAdding: .day, value: -offset, to: .now)!

        let entry = DayEntry(type: offset == 2 ? .frozen : .learned, at: date)

        container.mainContext.insert(entry)
        entry.goal = goal
    }

    return ActivityView(goal: goal)
        .modelContainer(container)
        .environment(AppClock())
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}
