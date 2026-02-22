import SwiftUI
import SwiftData
import UserNotifications

@main
struct FoodLoggerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([FoodEntry.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            #if DEBUG
            let storeURL = modelConfiguration.url
            try? FileManager.default.removeItem(at: storeURL)
            if let container = try? ModelContainer(for: schema, configurations: [modelConfiguration]) {
                return container
            }
            #endif
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.shortcutItems = [
            UIApplicationShortcutItem(
                type: "com.foodlogger.quicklog",
                localizedTitle: "Log Food Now",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "plus.circle")
            ),
            UIApplicationShortcutItem(
                type: "com.foodlogger.viewtoday",
                localizedTitle: "View Today",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "calendar.badge.clock")
            )
        ]
        return true
    }

    nonisolated func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        switch shortcutItem.type {
        case "com.foodlogger.quicklog":
            Task { @MainActor in
                NotificationCenter.default.post(name: .quickAction, object: "addEntry")
            }
        case "com.foodlogger.viewtoday":
            Task { @MainActor in
                NotificationCenter.default.post(name: .quickAction, object: "viewToday")
            }
        default:
            break
        }
        completionHandler(true)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let quickAction = Notification.Name("FoodLogger.quickAction")
    static let openAddEntry = Notification.Name("FoodLogger.openAddEntry")
    static let openWeeklyRecap = Notification.Name("FoodLogger.openWeeklyRecap")
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let action = userInfo["action"] as? String, action == "weeklyRecap" {
            Task { @MainActor in
                NotificationCenter.default.post(name: .openWeeklyRecap, object: nil)
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

// MARK: - App Root View

private struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allEntries: [FoodEntry]
    @State private var didSeed = false
    @State private var showRecapOnLaunch = false
    @State private var launchRecapSummary: WeeklySummary?

    var body: some View {
        AppShellView()
            .task {
                guard !didSeed else { return }
                didSeed = true
                SampleDataService().seedIfNeeded(context: modelContext)
                await checkAndShowMondayRecap()
                await rescheduleWeeklyRecapNotification()
            }
            .fullScreenCover(isPresented: $showRecapOnLaunch) {
                if let summary = launchRecapSummary {
                    WeeklyRecapView(summary: summary)
                }
            }
    }

    private func checkAndShowMondayRecap() async {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        // weekday 2 = Monday in Gregorian calendar
        guard weekday == 2 else { return }

        let todayKey = calendar.startOfDay(for: today)
            .formatted(.iso8601.year().month().day())

        let lastShown = UserDefaults.standard.string(forKey: "lastRecapShown") ?? ""
        guard lastShown != todayKey else { return }

        let summary = WeeklySummaryService().generateSummary(from: allEntries)
        launchRecapSummary = summary
        showRecapOnLaunch = true
        UserDefaults.standard.set(todayKey, forKey: "lastRecapShown")
    }

    private func rescheduleWeeklyRecapNotification() async {
        let summary = WeeklySummaryService().generateSummary(from: allEntries)
        await NotificationService().scheduleWeeklyRecap(summary: summary)
    }
}
