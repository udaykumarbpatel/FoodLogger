import SwiftUI
import SwiftData

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
}

// MARK: - App Root View

private struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var didSeed = false

    var body: some View {
        NavigationStack {
            DayLogView()
        }
        .task {
            guard !didSeed else { return }
            didSeed = true
            SampleDataService().seedIfNeeded(context: modelContext)
        }
    }
}
