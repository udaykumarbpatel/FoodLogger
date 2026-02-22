import SwiftUI
import SwiftData

// MARK: - App Shell

struct AppShellView: View {
    @Query private var allEntries: [FoodEntry]
    private let streakService = StreakService()

    private var streakInfo: StreakService.StreakInfo {
        streakService.compute(from: allEntries)
    }

    var body: some View {
        TabView {
            TodayTabView()
                .tabItem {
                    Label("Today", systemImage: "fork.knife")
                }

            CalendarTabView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            InsightsView(entries: allEntries)
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }

            SettingsView(hasLoggedToday: streakInfo.hasEntryToday)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

