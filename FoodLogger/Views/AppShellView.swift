import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

// MARK: - App Shell

struct AppShellView: View {
    @Query private var allEntries: [FoodEntry]
    private let streakService = StreakService()
    private let notificationService = NotificationService()

    @State private var showWeeklyRecap = false
    @State private var weeklyRecapSummary: WeeklySummary?

    // Milestone celebration
    @State private var activeMilestone: Int?
    @State private var showMilestoneOverlay = false
    private let milestones = [10, 25, 50, 100, 250]

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
        ZStack {
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

            // Milestone celebration overlay
            if showMilestoneOverlay, let milestone = activeMilestone {
                MilestoneOverlayView(milestone: milestone) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showMilestoneOverlay = false
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showMilestoneOverlay)
        .fullScreenCover(isPresented: $showWeeklyRecap) {
            if let summary = weeklyRecapSummary {
                WeeklyRecapView(summary: summary)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openWeeklyRecap)) { _ in
            weeklyRecapSummary = WeeklySummaryService().generateSummary(from: allEntries)
            showWeeklyRecap = true
        }
        .task {
            // Pre-mark milestones already exceeded at launch so we don't flood a new user.
            initMilestonesIfNeeded()
            await scheduleStreakRiskIfNeeded()
        }
        .onChange(of: allEntries.count) { oldCount, newCount in
            checkMilestones(oldCount: oldCount, newCount: newCount)
            Task { await scheduleStreakRiskIfNeeded() }
        }
    }

    // MARK: - Milestone helpers

    private func initMilestonesIfNeeded() {
        let key = "triggeredMilestones"
        guard (UserDefaults.standard.array(forKey: key) as? [Int])?.isEmpty ?? true,
              UserDefaults.standard.object(forKey: key) == nil else { return }
        // First run: mark every milestone already exceeded as triggered so they aren't shown.
        let currentCount = allEntries.count
        let alreadyPassed = milestones.filter { currentCount >= $0 }
        UserDefaults.standard.set(alreadyPassed, forKey: key)
    }

    private func checkMilestones(oldCount: Int, newCount: Int) {
        let key = "triggeredMilestones"
        var triggered = UserDefaults.standard.array(forKey: key) as? [Int] ?? []
        for milestone in milestones.sorted() {
            // Only celebrate when the threshold is crossed for the first time.
            if oldCount < milestone && newCount >= milestone && !triggered.contains(milestone) {
                triggered.append(milestone)
                UserDefaults.standard.set(triggered, forKey: key)
                activeMilestone = milestone
                withAnimation(.easeInOut(duration: 0.3)) {
                    showMilestoneOverlay = true
                }
                return // Show one milestone at a time.
            }
        }
    }

    private func scheduleStreakRiskIfNeeded() async {
        await notificationService.scheduleStreakRisk(
            currentStreak: streakInfo.count,
            hasLoggedToday: streakInfo.hasEntryToday
        )
    }
}

// MARK: - Milestone Overlay

private struct MilestoneOverlayView: View {
    let milestone: Int
    let onDismiss: () -> Void

    @State private var appeared = false

    private var milestoneMessage: String {
        switch milestone {
        case 10:  return "You're building a real habit. Keep logging!"
        case 25:  return "Your food journal is taking shape 📖"
        case 50:  return "50 entries! You're halfway to a century 🎯"
        case 100: return "A true food journalist. Incredible commitment 🏆"
        case 250: return "250 entries — you're a FoodLogger legend ⭐"
        default:  return "\(milestone) meals logged. Keep it up!"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            ConfettiView()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 20) {
                Text("🎉")
                    .font(.system(size: 60))
                    .scaleEffect(appeared ? 1 : 0.3)
                    .animation(.spring(duration: 0.6, bounce: 0.5), value: appeared)

                Text("\(milestone) Meals!")
                    .font(.system(.title, design: .rounded).bold())
                    .foregroundStyle(.white)

                Text(milestoneMessage)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                Button("Awesome!") { onDismiss() }
                    .font(.system(.headline, design: .rounded))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color.brandAccent)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(32)
            .background(Color.brandPrimary.opacity(0.95), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 40)
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.85)
            .animation(.spring(duration: 0.5, bounce: 0.3), value: appeared)
        }
        .onAppear { appeared = true }
    }
}
