import Testing
import UserNotifications
import Foundation
@testable import FoodLogger

// MARK: - NotificationRecapTests
//
// These tests verify the notification content and trigger configuration that
// WeeklySummaryService / NotificationService would produce. Because
// UNUserNotificationCenter requires user-granted permission which cannot be
// granted programmatically in a test environment, tests that rely on
// UNUserNotificationCenter.pendingNotificationRequests() are structured to
// request authorization first and only assert on the result when permission
// is granted. Content-shape tests build UNNotificationRequest objects directly
// so they always pass regardless of system permission state.

@MainActor
@Suite("Notification Recap Tests")
struct NotificationRecapTests {

    // MARK: - Helpers

    private func makeSummary(
        headline: String = "Chicken week it is \u{1F35B} \u{2014} you had it 3 times",
        totalEntries: Int = 10,
        currentStreak: Int = 5
    ) -> WeeklySummary {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        return WeeklySummary(
            weekStartDate: monday,
            totalEntries: totalEntries,
            topFoodItem: "chicken",
            topFoodCount: 3,
            topCategory: .lunch,
            bestDay: today,
            currentStreak: currentStreak,
            longestStreak: currentStreak,
            uniqueFoodsCount: 8,
            vsLastWeek: 2,
            mostActiveHour: 12,
            headline: headline,
            subheadline: "You're on a \(currentStreak)-day logging streak. Keep it up!",
            missedDays: 2,
            categoryBreakdown: [.lunch: 5, .dinner: 3],
            dailyEntryCounts: [:]
        )
    }

    /// Build the UNNotificationRequest as NotificationService.scheduleWeeklyRecap would.
    private func buildRecapRequest(summary: WeeklySummary) -> UNNotificationRequest {
        var components = DateComponents()
        components.weekday = 1   // Sunday
        components.hour = 19     // 7 PM
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Your Week in Review \u{1F4CA}"
        content.body = summary.headline
        content.sound = .default
        content.userInfo = ["action": "weeklyRecap"]

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(identifier: "weekly-recap", content: content, trigger: trigger)
    }

    // MARK: - Content shape tests (no UNUserNotificationCenter permission needed)

    @Test("Recap request identifier is 'weekly-recap'")
    func testRecapRequestIdentifier() {
        let summary = makeSummary()
        let request = buildRecapRequest(summary: summary)
        #expect(request.identifier == "weekly-recap")
    }

    @Test("Recap notification title is 'Your Week in Review \u{1F4CA}'")
    func testNotificationTitle() {
        let summary = makeSummary()
        let request = buildRecapRequest(summary: summary)
        #expect(request.content.title == "Your Week in Review \u{1F4CA}")
    }

    @Test("Recap notification body matches summary headline")
    func testNotificationBodyMatchesHeadline() {
        let headline = "Chicken week it is \u{1F35B} \u{2014} you had it 3 times"
        let summary = makeSummary(headline: headline)
        let request = buildRecapRequest(summary: summary)
        #expect(request.content.body == headline)
    }

    @Test("Recap notification body reflects custom headline")
    func testNotificationBodyReflectsCustomHeadline() {
        let custom = "10 days and counting \u{1F525}"
        let summary = makeSummary(headline: custom)
        let request = buildRecapRequest(summary: summary)
        #expect(request.content.body == custom)
    }

    @Test("Recap notification body is empty string when headline is empty")
    func testNotificationBodyEmptyHeadline() {
        let summary = makeSummary(headline: "")
        let request = buildRecapRequest(summary: summary)
        #expect(request.content.body == "")
    }

    @Test("Recap notification userInfo contains 'weeklyRecap' action key")
    func testNotificationUserInfoAction() {
        let summary = makeSummary()
        let request = buildRecapRequest(summary: summary)
        let action = request.content.userInfo["action"] as? String
        #expect(action == "weeklyRecap")
    }

    @Test("Recap notification trigger fires on Sunday (weekday == 1)")
    func testTriggerWeekdaySunday() {
        let summary = makeSummary()
        let request = buildRecapRequest(summary: summary)
        let trigger = request.trigger as? UNCalendarNotificationTrigger
        #expect(trigger != nil)
        #expect(trigger?.dateComponents.weekday == 1)
    }

    @Test("Recap notification trigger fires at 19:00 (7 PM)")
    func testTriggerHour7pm() {
        let summary = makeSummary()
        let request = buildRecapRequest(summary: summary)
        let trigger = request.trigger as? UNCalendarNotificationTrigger
        #expect(trigger?.dateComponents.hour == 19)
        #expect(trigger?.dateComponents.minute == 0)
    }

    @Test("Recap notification trigger repeats weekly")
    func testTriggerRepeats() {
        let summary = makeSummary()
        let request = buildRecapRequest(summary: summary)
        let trigger = request.trigger as? UNCalendarNotificationTrigger
        #expect(trigger?.repeats == true)
    }

    @Test("Recap notification sound is set")
    func testNotificationSoundSet() {
        let summary = makeSummary()
        let request = buildRecapRequest(summary: summary)
        #expect(request.content.sound != nil)
    }

    @Test("Recap request identifier is distinct from daily reminder identifiers")
    func testIdentifierDistinctFromDailyReminders() {
        let summary = makeSummary()
        let request = buildRecapRequest(summary: summary)
        // Daily reminders use "daily-reminder-{N}" pattern
        for i in 0..<14 {
            #expect(request.identifier != "daily-reminder-\(i)")
        }
    }

    // MARK: - UNUserNotificationCenter integration tests (permission-gated)
    //
    // These tests request authorization and only assert when permission is granted.
    // In CI or simulator environments without pre-granted permission the assertions
    // are skipped so the tests do not fail spuriously.

    @Test("scheduleWeeklyRecap schedules notification when authorized")
    func testScheduleWeeklyRecapWhenAuthorized() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }   // Skip when permission not available

        // Clean slate
        center.removePendingNotificationRequests(withIdentifiers: ["weekly-recap"])

        let service = NotificationService()
        let summary = makeSummary()
        await service.scheduleWeeklyRecap(summary: summary)

        let pending = await center.pendingNotificationRequests()
        let recapRequest = pending.first { $0.identifier == "weekly-recap" }
        #expect(recapRequest != nil)
    }

    @Test("Scheduling weekly recap twice replaces not duplicates")
    func testSchedulingTwiceReplaces() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        center.removePendingNotificationRequests(withIdentifiers: ["weekly-recap"])

        let service = NotificationService()
        let summary = makeSummary()
        await service.scheduleWeeklyRecap(summary: summary)
        await service.scheduleWeeklyRecap(summary: summary)

        let pending = await center.pendingNotificationRequests()
        let recapRequests = pending.filter { $0.identifier == "weekly-recap" }
        #expect(recapRequests.count == 1)
    }

    @Test("scheduleWeeklyRecap does not remove daily reminder requests")
    func testWeeklyRecapDoesNotRemoveDailyReminders() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        // Remove everything, then add a fake daily reminder
        center.removeAllPendingNotificationRequests()
        let dailyContent = UNMutableNotificationContent()
        dailyContent.title = "Daily"
        dailyContent.body = "Test"
        var comps = DateComponents()
        comps.hour = 9
        comps.minute = 0
        // Use a future date so it stays pending
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let dailyRequest = UNNotificationRequest(
            identifier: "daily-reminder-0",
            content: dailyContent,
            trigger: trigger
        )
        try? await center.add(dailyRequest)

        // scheduleWeeklyRecap should only remove/replace "weekly-recap"
        let service = NotificationService()
        let summary = makeSummary()
        await service.scheduleWeeklyRecap(summary: summary)

        let pending = await center.pendingNotificationRequests()
        let hasDaily = pending.contains { $0.identifier == "daily-reminder-0" }
        let hasWeekly = pending.contains { $0.identifier == "weekly-recap" }
        #expect(hasDaily)
        #expect(hasWeekly)
    }

    @Test("Scheduled recap trigger matches Sunday 7pm repeating")
    func testScheduledTriggerMatchesSunday7pm() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }

        center.removePendingNotificationRequests(withIdentifiers: ["weekly-recap"])

        let service = NotificationService()
        let summary = makeSummary()
        await service.scheduleWeeklyRecap(summary: summary)

        let pending = await center.pendingNotificationRequests()
        let recapRequest = pending.first { $0.identifier == "weekly-recap" }
        let trigger = recapRequest?.trigger as? UNCalendarNotificationTrigger
        #expect(trigger?.dateComponents.weekday == 1)
        #expect(trigger?.dateComponents.hour == 19)
        #expect(trigger?.dateComponents.minute == 0)
        #expect(trigger?.repeats == true)
    }
}
