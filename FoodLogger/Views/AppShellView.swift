import SwiftUI
import SwiftData

// MARK: - App Shell

struct AppShellView: View {
    @Query private var allEntries: [FoodEntry]
    private let streakService = StreakService()
    @State private var showWeeklyRecap = false
    @State private var weeklyRecapSummary: WeeklySummary?

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
        .fullScreenCover(isPresented: $showWeeklyRecap) {
            if let summary = weeklyRecapSummary {
                WeeklyRecapView(summary: summary)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWeeklyRecap)) { _ in
            weeklyRecapSummary = WeeklySummaryService().generateSummary(from: allEntries)
            showWeeklyRecap = true
        }
    }
}

