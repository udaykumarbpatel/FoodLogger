import SwiftUI
import SwiftData

@main
struct FoodLoggerApp: App {

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
            CalendarHomeView()
        }
        .modelContainer(sharedModelContainer)
    }
}
