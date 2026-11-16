//
//  GoalLogicTest.swift
//  Learner
//
//  Created by Njoud Altalal on 05/06/1448 AH.
//
//
//  GoalLogicTests.swift
//  Learner
//
// Only compiled inside a Unit Testing target (the app target has no `Testing` module).
#if canImport(Testing)
import Testing
import Foundation
import SwiftData
@testable import Learner

@MainActor
struct GoalLogicTests {

    /// Keeps the container alive for the whole test.
    private struct Env {
        let container: ModelContainer
        var context: ModelContext { container.mainContext }

        init() throws {
            container = try ModelContainer(
                for: Goal.self, DayEntry.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }

    /// Fixed dates, so tests never depend on the real clock.
    private func time(day: Int, hour: Int = 9) -> Date {
        let calendar = Calendar.current
        let base = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let date = calendar.date(byAdding: .day, value: day, to: base)!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
    }

    private func makeGoal(_ duration: GoalDuration = .week, in env: Env) -> Goal {
        let goal = Goal(title: "Swift", duration: duration, startDate: time(day: 0))
        env.context.insert(goal)
        return goal
    }

    @Test func loggingLearnedCountsTheDayAndLocksFreeze() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        goal.logLearned(now: time(day: 0), in: env.context)

        #expect(goal.learnedCount == 1)
        #expect(!goal.canFreeze(now: time(day: 0)))
        #expect(!goal.canLog(now: time(day: 0)))   // a new log is locked; only undo remains
    }

    @Test func freezingLocksLog() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        goal.freezeToday(now: time(day: 0), in: env.context)

        #expect(goal.frozenCount == 1)
        #expect(!goal.canLog(now: time(day: 0)))
        #expect(!goal.canFreeze(now: time(day: 0)))
    }

    @Test func pressingLoggedAgainUndoesIt() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        goal.logLearned(now: time(day: 0), in: env.context)
        goal.logLearned(now: time(day: 0), in: env.context)   // same button = undo

        #expect(goal.learnedCount == 0)
        #expect(goal.canLog(now: time(day: 0)))
        #expect(goal.canFreeze(now: time(day: 0)))
    }

    @Test func pressingFreezedAgainGivesTheFreezeBack() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        goal.freezeToday(now: time(day: 0), in: env.context)
        #expect(goal.freezesRemaining == 1)

        goal.freezeToday(now: time(day: 0), in: env.context)  // same button = undo
        #expect(goal.freezesRemaining == 2)
        #expect(goal.canLog(now: time(day: 0)))
    }

    @Test func weekGoalAllowsOnlyTwoFreezes() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        goal.freezeToday(now: time(day: 0), in: env.context)
        goal.freezeToday(now: time(day: 1), in: env.context)

        #expect(!goal.canFreeze(now: time(day: 2)))
        #expect(goal.canLog(now: time(day: 2)))
    }

    @Test func buttonsComeBackAtMidnight() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        goal.logLearned(now: time(day: 0, hour: 23), in: env.context)

        #expect(!goal.canLog(now: time(day: 0, hour: 23)))
        #expect(goal.canLog(now: time(day: 1, hour: 0)))
    }

    @Test func goalFailsAfter32HoursWithoutAnEntry() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        goal.logLearned(now: time(day: 0, hour: 9), in: env.context)

        goal.refresh(now: time(day: 1, hour: 16))   // 31 hours
        #expect(goal.status == .active)

        goal.refresh(now: time(day: 1, hour: 18))   // 33 hours
        #expect(goal.status == .failed)
    }

    @Test func sevenDaysCompleteAWeekGoal() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        for day in 0..<7 {
            goal.logLearned(now: time(day: day), in: env.context)
        }

        #expect(goal.status == .completed)
    }

    @Test func undoOnTheLastDayReopensTheGoal() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        for day in 0..<7 {
            goal.logLearned(now: time(day: day), in: env.context)
        }
        #expect(goal.status == .completed)

        goal.logLearned(now: time(day: 6), in: env.context)   // same button = undo
        #expect(goal.status == .active)
        #expect(goal.learnedCount == 6)
    }

    @Test func failedGoalCannotBeUndone() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        goal.logLearned(now: time(day: 0), in: env.context)
        goal.refresh(now: time(day: 3))

        #expect(goal.status == .failed)
        #expect(!goal.canUndo(.learned, now: time(day: 0)))
    }

    // MARK: - More rules

    @Test func onlyOneEntryPerDay() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        goal.logLearned(now: time(day: 0, hour: 9), in: env.context)
        goal.freezeToday(now: time(day: 0, hour: 10), in: env.context)   // locked: already logged

        #expect(goal.learnedCount == 1)
        #expect(goal.frozenCount == 0)
    }

    @Test func undoOnlyWorksOnTheSameDay() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        goal.logLearned(now: time(day: 0), in: env.context)

        #expect(goal.canUndo(.learned, now: time(day: 0)))
        #expect(!goal.canUndo(.learned, now: time(day: 1)))   // yesterday's entry is final
    }

    @Test func freezedDaysCountTowardCompletion() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        for day in 0..<7 {
            if day == 2 || day == 3 {
                goal.freezeToday(now: time(day: day), in: env.context)
            } else {
                goal.logLearned(now: time(day: day), in: env.context)
            }
        }

        #expect(goal.learnedCount == 5)
        #expect(goal.frozenCount == 2)
        #expect(goal.status == .completed)
    }

    @Test func monthGoalAllowsEightFreezes() throws {
        let env = try Env()
        let goal = makeGoal(.month, in: env)

        for day in 0..<8 {
            goal.freezeToday(now: time(day: day), in: env.context)
        }

        #expect(goal.freezesRemaining == 0)
        #expect(!goal.canFreeze(now: time(day: 8)))
        #expect(goal.canLog(now: time(day: 8)))
    }

    @Test func endedGoalLocksBothButtons() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        goal.refresh(now: time(day: 3))   // nothing logged for 3 days

        #expect(goal.status == .failed)
        #expect(!goal.canLog(now: time(day: 3)))
        #expect(!goal.canFreeze(now: time(day: 3)))
    }

    @Test func nextRefreshIsAlwaysInTheFuture() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        goal.logLearned(now: time(day: 0, hour: 9), in: env.context)

        let now = time(day: 0, hour: 10)
        #expect(goal.nextRefreshDate(now: now) > now)
    }

    // MARK: - View models

    @Test func onboardingNeedsANonEmptyGoal() {
        let viewModel = OnboardingViewModel()
        #expect(!viewModel.canStart)

        viewModel.goalTitle = "   "
        #expect(!viewModel.canStart)

        viewModel.goalTitle = "Swift"
        #expect(viewModel.canStart)
    }

    @Test func editorNeedsARealChangeWhileTheGoalRuns() throws {
        let env = try Env()
        let goal = makeGoal(in: env)
        let viewModel = GoalEditorViewModel(goal: goal)

        #expect(!viewModel.canConfirm)          // nothing changed yet
        #expect(viewModel.needsConfirmation)    // a running goal asks first

        viewModel.title = "SwiftUI"
        #expect(viewModel.canConfirm)
    }

    @Test func savingTheEditorEndsTheOldGoalAndStartsANewOne() throws {
        let env = try Env()
        let goal = makeGoal(in: env)
        let viewModel = GoalEditorViewModel(goal: goal)

        viewModel.title = "SwiftUI"
        viewModel.saveGoal(now: time(day: 1), in: env.context)

        let goals = try env.context.fetch(FetchDescriptor<Goal>())
        #expect(goals.count == 2)
        #expect(goal.status == .failed)
        #expect(goals.contains { $0.title == "SwiftUI" && $0.status == .active })
    }

    @Test func setGoalIsPrefilledAndStartsAFreshGoal() throws {
        let env = try Env()
        let old = makeGoal(in: env)
        old.status = .completed

        let viewModel = SetGoalViewModel(previous: old)
        #expect(viewModel.title == "Swift")
        #expect(viewModel.duration == .week)
        #expect(viewModel.canStart)

        viewModel.start(now: time(day: 8), in: env.context)

        let goals = try env.context.fetch(FetchDescriptor<Goal>())
        #expect(goals.count == 2)
        #expect(goals.filter { $0.status == .active }.count == 1)
    }

    @Test func calendarLetsLearnedWinOverFreezed() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        // Two goals logged the same day, in both orders.
        let a = DayEntry(type: .frozen, goal: goal, at: time(day: 0))
        let b = DayEntry(type: .learned, goal: goal, at: time(day: 0, hour: 10))
        env.context.insert(a)
        env.context.insert(b)

        let viewModel = CalendarViewModel()
        let day = Calendar.current.startOfDay(for: time(day: 0))

        #expect(viewModel.typeByDay(entries: [a, b])[day] == .learned)
        #expect(viewModel.typeByDay(entries: [b, a])[day] == .learned)
    }

    @Test func monthLayoutKnowsHowManyDaysAMonthHas() {
        let february = Calendar.current.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        #expect(MonthLayout(month: february).dayCount == 28)
    }
    @Test func usingAllFreezesDoesNotFailTheGoal() throws {
        let env = try Env()
        let goal = makeGoal(in: env)

        goal.freezeToday(now: time(day: 0), in: env.context)
        goal.freezeToday(now: time(day: 1), in: env.context)

        // Day 3: only the Freeze button is off. The goal keeps running.
        #expect(goal.status == .active)
        #expect(goal.freezesRemaining == 0)
        #expect(!goal.canFreeze(now: time(day: 2)))
        #expect(goal.canLog(now: time(day: 2)))

        // Logging the other five days completes the goal.
        for day in 2..<7 {
            goal.logLearned(now: time(day: day), in: env.context)
        }
        #expect(goal.status == .completed)
        #expect(goal.learnedCount == 5)
        #expect(goal.frozenCount == 2)
    }
}
#endif
