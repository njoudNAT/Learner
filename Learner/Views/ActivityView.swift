import SwiftUI
import SwiftData

struct ActivityView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppClock.self) private var clock

    @State private var viewModel: ActivityViewModel

    /// The Log circle and the Freeze button share one width, as in the Sketch.
    private let controlWidth: CGFloat = 240

    init(goal: Goal) {
        _viewModel = State(initialValue: ActivityViewModel(goal: goal))
    }

    private var goal: Goal { viewModel.goal }
    private var now: Date { clock.now }
    private var todayState: TodayState { viewModel.todayState(now: now) }

    var body: some View {
        NavigationStack(path: $viewModel.path) {
            ScrollView {
                VStack(spacing: 28) {
                    header
                    WeekStrip(goal: goal, now: now)
                    statCards
                    stateContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .animation(.smooth, value: todayState)
                .animation(.smooth, value: viewModel.status)
            }
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .background(Color(.systemBackground))
            .toolbar(.hidden, for: .navigationBar)   // custom header, as in the Sketch
            .navigationDestination(for: ActivityRoute.self) { route in
                switch route {
                case .calendar:
                    CalendarView()
                case .goalEditor:
                    GoalEditorView(goal: goal)
                case .setGoal:
                    SetGoalView(previous: goal)
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
        .sensoryFeedback(trigger: viewModel.learnedCount) { old, new in
            new > old ? SensoryFeedback.success : SensoryFeedback.impact(weight: .light)
        }
        .sensoryFeedback(trigger: viewModel.frozenCount) { old, new in
            new > old ? SensoryFeedback.impact : SensoryFeedback.impact(weight: .light)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Activity")
                    .font(.largeTitle.bold())
                    .modifier(DebugPanelTrigger())   // long-press: debug panel (debug builds only)

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

    // MARK: - State content

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.status {

        case .active:
            VStack(spacing: 20) {
                logButton
                freezeSection
            }
            .padding(.top, 16)

        case .completed:
            EndState(
                icon: .symbol("hands.clap.fill"),
                title: "Well done!",
                message: "Ready for your next goal?",
                onSetGoal: viewModel.showSetGoal,
                showsUndo: viewModel.canUndoToday(now: now),
                onUndo: { viewModel.undoToday(clock: clock, in: modelContext) }
            )

        case .failed:
            EndState(
                icon: .symbol("xmark.seal.fill"),
                title: "You didn’t reach your goal this time.",
                message: "Want to set another goal?",
                onSetGoal: viewModel.showSetGoal
            )
        }
    }

    // MARK: - Log circle

    private var logButton: some View {
        let isLogged = todayState == .learned
        let isHighlighted = viewModel.canLog(now: now)      // a NEW log is possible
        let isTappable = viewModel.canTapLog(now: now)      // new log, or undo

        return Button {
            viewModel.logLearned(clock: clock, in: modelContext)
        } label: {
            Text(isLogged ? "Logged as Learned" : "Log as Learned")
                .font(.title3.weight(.semibold))
                .foregroundStyle(isHighlighted ? Color.white : Color.secondary)
                .frame(width: controlWidth, height: controlWidth)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isHighlighted
                ? .regular.tint(Color.brandOrange).interactive()
                : (isTappable ? .regular.interactive() : .regular),
            in: .circle
        )
        .disabled(!isTappable)
        .accessibilityHint(isLogged ? "Double-tap to undo" : "")
    }

    // MARK: - Freeze button (same width as the circle, directly under it)

    private var freezeSection: some View {
        VStack(spacing: 10) {
            freezeButton

            Text(viewModel.freezeSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var freezeButton: some View {
        let isFrozen = todayState == .frozen

        let label = Text(isFrozen ? "Freezed for a day" : "Freeze for a day")
            .font(.headline)
            .frame(width: controlWidth)
            .padding(.vertical, 6)

        if viewModel.canFreeze(now: now) {
            // A new freeze is possible: blue.
            Button {
                viewModel.freezeToday(clock: clock, in: modelContext)
            } label: {
                label.foregroundStyle(Color.white)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.brandFreezeBlue)
            .controlSize(.large)
        } else {
            // Disabled, or "Freezed for a day" (tap again to undo): dark glass, gray text.
            Button {
                viewModel.freezeToday(clock: clock, in: modelContext)
            } label: {
                label.foregroundStyle(Color.secondary)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .disabled(!viewModel.canTapFreeze(now: now))
            .accessibilityHint(isFrozen ? "Double-tap to undo" : "")
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

// MARK: - Stat card

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

// MARK: - End states ("Well done!" and "not met"): no Log or Freeze controls, as in the Sketch

private enum EndIcon {
    case symbol(String)
    case emoji(String)
}

private struct EndState: View {
    let icon: EndIcon
    let title: String
    let message: String
    let onSetGoal: () -> Void
    var showsUndo = false
    var onUndo: () -> Void = { }

    var body: some View {
        VStack(spacing: 12) {
            iconView
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(action: onSetGoal) {
                Label("Set a goal", systemImage: "pencil.and.outline")
                    .font(.headline)
            }
            .buttonStyle(.glassProminent)
            .tint(Color.brandOrange)
            .controlSize(.large)
            .padding(.top, 8)

            // Only on the day the goal was completed: reverses a mis-tap on the last day.
            if showsUndo {
                Button("Undo today’s entry", action: onUndo)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 40)
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .symbol(let name):
            Image(systemName: name)
                .font(.system(size: 44))
                .foregroundStyle(Color.brandOrange)
        case .emoji(let text):
            Text(text)
                .font(.system(size: 48))
        }
    }
}
// MARK: - Preview

#Preview("Activity") {
    let container = try! ModelContainer(
        for: Goal.self, DayEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let goal = Goal(title: "Swift", duration: .week)
    container.mainContext.insert(goal)

    return ActivityView(goal: goal)
        .modelContainer(container)
        .environment(AppClock())
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}
