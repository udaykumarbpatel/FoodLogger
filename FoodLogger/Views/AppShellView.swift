import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

// MARK: - App Shell

struct AppShellView: View {
    @Query private var allEntries: [FoodEntry]
    private let streakService = StreakService()
    @State private var showWeeklyRecap = false
    @State private var weeklyRecapSummary: WeeklySummary?

    init() {
        #if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.brandPrimary)

        let orange = UIColor(Color.brandAccent)
        appearance.stackedLayoutAppearance.selected.iconColor = orange
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: orange,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

        let dimWhite = UIColor.white.withAlphaComponent(0.4)
        appearance.stackedLayoutAppearance.normal.iconColor = dimWhite
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: dimWhite,
            .font: UIFont.systemFont(ofSize: 10, weight: .regular)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        #endif
    }

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
                    Label("Settings", systemImage: "gearshape.fill")
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
