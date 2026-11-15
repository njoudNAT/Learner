//
//  NotificationService.swift
//  Learner
//
//  Created by Njoud Altalal on 05/06/1448 AH.
//
import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private let reminderHour = 20                         // 8:00 PM
    private let reminderDaysAhead = 7
    private let warningLead: TimeInterval = 3 * 60 * 60   // 3 h before the 32 h deadline
    private let streakWindow: TimeInterval = 32 * 60 * 60

    private init() {}

    // MARK: - Permission

    /// Ask when the user commits to a goal (Start Learning), not at launch.
    @discardableResult
    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: - Scheduling

    /// Rebuilds every pending notification from the goal's current state.
    func sync(goal: Goal, now: Date) async {
        center.removeAllPendingNotificationRequests()

        guard goal.status == .active else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }

        let calendar = Calendar.current

        // 1. Daily reminders at 8 PM. Today's is skipped once today is logged or freezed.
        for dayOffset in 0..<reminderDaysAhead {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now),
                  let fire = calendar.date(bySettingHour: reminderHour, minute: 0, second: 0, of: day),
                  fire > now else { continue }

            if dayOffset == 0 && goal.todayState(now: now) != .notLogged { continue }

            await schedule(
                id: "reminder-\(dayOffset)",
                title: "Time to learn \(goal.title)",
                body: "Log today to keep your streak going.",
                at: fire
            )
        }

        // 2. Streak warning, 3 hours before the 32-hour deadline.
        let last = goal.entries.map(\.loggedAt).max() ?? goal.startDate
        let warning = last.addingTimeInterval(streakWindow - warningLead)

        if warning > now {
            await schedule(
                id: "warning",
                title: "Your streak is about to end",
                body: "Log or freeze today to keep learning \(goal.title).",
                at: warning
            )
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Debug helpers

    func sendTest() async {
        let content = UNMutableNotificationContent()
        content.title = "Test notification"
        content.body = "Notifications are working."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "test", content: content, trigger: trigger))
    }

    func pendingSummary() async -> [String] {
        let requests = await center.pendingNotificationRequests()

        let items: [(Date, String)] = requests.compactMap { request in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                  let date = trigger.nextTriggerDate() else { return nil }
            let text = "\(date.formatted(date: .abbreviated, time: .shortened)) · \(request.content.title)"
            return (date, text)
        }

        return items.sorted { $0.0 < $1.0 }.map(\.1)
    }

    // MARK: - Private

    private func schedule(id: String, title: String, body: String, at date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let parts = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)

        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
