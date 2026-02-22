import UserNotifications

@MainActor
final class NotificationService {

    private let center = UNUserNotificationCenter.current()

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    func scheduleReminders(at time: Date, hasLoggedToday: Bool) async {
        await center.removeAllPendingNotificationRequests()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let hour = calendar.component(.hour, from: time)
        let minute = calendar.component(.minute, from: time)
        let now = Date()

        for dayOffset in 0..<14 {
            guard let targetDay = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }

            // Skip today if the user already logged
            if dayOffset == 0 && hasLoggedToday { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: targetDay)
            components.hour = hour
            components.minute = minute

            // Skip if the target time has already passed
            guard let triggerDate = calendar.date(from: components), triggerDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Food Journal"
            content.body = "Don't forget to log what you ate today 🍽️"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: "daily-reminder-\(dayOffset)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
