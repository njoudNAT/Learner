//
//  ActivityView.swift
//  Learner
//
//  Created by Njoud Altalal on 30/05/1448 AH.
//
import SwiftUI
import SwiftData

/// Main page. Requires iOS 26 (Liquid Glass).
struct ActivityView: View {
    let goal: Goal

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var clock = Date()
    @State private var debugOffset: TimeInterval = 0   // only changed by the debug menu

    private var now: Date { clock.addingTimeInterval(debugOffset) }
    private var todayState: TodayState { goal.todayState(now: now) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    WeekStrip(goal: goal, now: now)
                        .modifier(DebugTimeTravel(offset: $debugOffset))

                    statCards
                    stateContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .animation(.smooth, value: todayState)
                .animation(.smooth, value: goal.status)
            }
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .navigationTitle("Activity")
            .navigationSubtitle(now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        CalendarView(now: now)
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("Calendar")

                    NavigationLink {
                        GoalEditorView(goal: goal, now: now)
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("Edit learning goal")
                }
            }
            .safeAreaInset(edge: .bottom) { freezeFooter }
        }
        .task(id: debugOffset) { await runClock() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                clock = .now
                goal.refresh(now: now)
            }
        }
        .sensoryFeedback(.success, trigger: goal.learnedCount)
        .sensoryFeedback(.impact, trigger: goal.frozenCount)
    }

    // MARK: - Sections

    private var statCards: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                StatCard(symbol: "flame.fill", tint: Color.brandOrange,
                         count: goal.learnedCount, caption: "Learned")
                StatCard(symbol: "snowflake", tint: Color.brandFreezeBlue,
                         count: goal.frozenCount, caption: "Freezed")
            }
        }
    }

    @ViewBuilder
    private var stateContent: some View {
        switch goal.status {
        case .active:
            logButton
        case .completed:
            EndState(goal: goal, now: now,
                     symbol: "hands.clap.fill",
                     title: "Well done!",
                     message: "Ready for your next goal?")
        case .failed:
            EndState(goal: goal, now: now,
                     symbol: "xmark.seal.fill",
                     title: "You didn’t reach your goal this time.",
                     message: "Want to set another goal?")
        }
    }

    private var logButton: some View {
        let isLogged = todayState == .learned
        return Button {
            goal.logLearned(now: now, in: modelContext)
        } label: {
            Text(isLogged ? "Logged as Learned" : "Log as Learned")
                .font(.title3.weight(.semibold))
                .foregroundStyle(isLogged ? Color.secondary : Color.white)
                .frame(width: 240, height: 240)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isLogged
                ? .regular.interactive()
                : .regular.tint(Color.brandOrange).interactive(),
            in: .circle
        )
        .disabled(!goal.canLog(now: now))
        .padding(.top, 24)
    }

    @ViewBuilder
    private var freezeFooter: some View {
        if goal.status == .active {
            VStack(spacing: 8) {
                Button {
                    goal.freezeToday(now: now, in: modelContext)
                } label: {
                    Text(todayState == .frozen ? "Freezed for a day" : "Freeze for a day")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Color.brandFreezeBlue)
                .controlSize(.large)
                .disabled(!goal.canFreeze(now: now))

                Text("\(goal.frozenCount) out of \(goal.duration.maxFreezes) Freezes used")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Clock

    /// Re-checks the goal at midnight and at the 32-hour deadline,
    /// so the screen updates itself while the app stays open.
    private func runClock() async {
        while !Task.isCancelled {
            clock = .now
            goal.refresh(now: now)
            let wake = goal.nextRefreshDate(now: now)
            let seconds = max(1, wake.timeIntervalSince(now))
            try? await Task.sleep(for: .seconds(seconds))
        }
    }
}

// MARK: - Week strip

private struct WeekStrip: View {
    let goal: Goal
    let now: Date

    private var days: [Date] {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
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

// MARK: - Cards and states

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
    let goal: Goal
    let now: Date
    let symbol: String
    let title: String
    let message: String

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

            NavigationLink {
                GoalEditorView(goal: goal, now: now)
            } label: {
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

// MARK: - Debug time travel (does nothing in release builds)

private struct DebugTimeTravel: ViewModifier {
    @Binding var offset: TimeInterval
    @State private var isShowing = false

    func body(content: Content) -> some View {
        #if DEBUG
        content
            .onLongPressGesture(minimumDuration: 1) { isShowing = true }
            .confirmationDialog("Time travel (debug only)", isPresented: $isShowing) {
                Button("+1 hour") { offset += 3_600 }
                Button("+1 day") { offset += 86_400 }
                Button("+33 hours") { offset += 118_800 }
                Button("Reset time", role: .destructive) { offset = 0 }
            }
        #else
        content
        #endif
    }
}

#Preview {
    let container = try! ModelContainer(
        for: Goal.self, DayEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let goal = Goal(title: "Swift", duration: .week)
    container.mainContext.insert(goal)
    return ActivityView(goal: goal)
        .modelContainer(container)
        .preferredColorScheme(.dark)
        .tint(Color.brandOrange)
}
