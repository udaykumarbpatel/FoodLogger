//
//  InsightsView.swift
//  FoodLogger
//
//  Analytics dashboard: top foods, daily activity, category distribution,
//  meal timing, week-over-week trend, monthly heatmap, food search, and stats.
//

import SwiftUI
import Charts

// MARK: - InsightsView

struct InsightsView: View {

    let entries: [FoodEntry]

    @State private var selectedPeriod: AnalyticsPeriod = .month
    @State private var heatmapMonth: Date = Date()
    @State private var searchText: String = ""
    @State private var weeklySummary: WeeklySummary?

    private let service = InsightsService()
    private let summaryService = WeeklySummaryService()

    // MARK: - Derived data

    private var topFoods: [FoodItemFrequency] {
        service.topItems(from: entries, period: selectedPeriod, limit: 10)
    }

    private var dailyData: [DailyCount] {
        service.dailyCounts(from: entries, period: selectedPeriod)
    }

    private var categoryData: [CategoryCount] {
        service.categoryDistribution(from: entries, period: selectedPeriod)
    }

    private var timingData: [HourCount] {
        service.mealTiming(from: entries, period: selectedPeriod)
    }

    private var weekTrend: WeekComparison {
        service.weekOverWeekTrend(from: entries)
    }

    private var heatmapData: [DayActivity] {
        service.monthlyHeatmap(from: entries, month: heatmapMonth)
    }

    private var allTimeTopFoods: [FoodItemFrequency] {
        service.topItems(from: entries, period: .allTime, limit: 100)
    }

    private var filteredSearchFoods: [FoodItemFrequency] {
        guard !searchText.isEmpty else { return [] }
        return allTimeTopFoods.filter {
            $0.item.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var totalEntriesInPeriod: Int {
        service.filterByPeriod(entries, period: selectedPeriod).count
    }

    private var consistencyFraction: Double {
        let periodDays: Int
        switch selectedPeriod {
        case .week:        periodDays = 7
        case .month:       periodDays = 30
        case .threeMonths: periodDays = 90
        case .year:        periodDays = 365
        case .allTime:
            let calendar = Calendar.current
            if let earliest = entries.map({ $0.date }).min() {
                let days = calendar.dateComponents([.day], from: earliest, to: Date()).day ?? 1
                periodDays = max(days, 1)
            } else {
                return 0
            }
        }
        let daysWithEntries = Set(
            service.filterByPeriod(entries, period: selectedPeriod)
                .map { Calendar.current.startOfDay(for: $0.date) }
        ).count
        return Double(daysWithEntries) / Double(periodDays)
    }

    private var longestStreak: Int {
        let calendar = Calendar.current
        let days = Set(entries.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<days.count {
            let diff = calendar.dateComponents([.day], from: days[i - 1], to: days[i]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    private var streakInfo: StreakService.StreakInfo {
        StreakService().compute(from: entries)
    }

    /// Most entries logged on any single day (all-time).
    private var mostLoggedDayCount: Int {
        let calendar = Calendar.current
        var dayCounts: [Date: Int] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            dayCounts[day, default: 0] += 1
        }
        return dayCounts.values.max() ?? 0
    }

    /// Count of distinct non-stopword food tokens seen in all entries.
    private var totalUniqueFoods: Int { allTimeTopFoods.count }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            storyHeadlineCard
                                .padding(.top, 8)

                            periodPicker
                                .padding(.horizontal, 16)

                            statsCard
                            recordsCard
                            topFoodsCard
                            dailyActivityCard
                            categoryCard
                            mealTimingCard
                            weekTrendCard
                            heatmapCard
                            foodSearchCard
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                weeklySummary = summaryService.generateSummary(from: entries)
            }
        }
    }

    // MARK: - Story Headline

    @ViewBuilder
    private var storyHeadlineCard: some View {
        if let summary = weeklySummary, !entries.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("This Week", systemImage: "sparkles")
                    .font(.appCaption)
                    .foregroundStyle(Color.accentColor)

                Text(summary.headline)
                    .font(.appHeadline)
                    .foregroundStyle(.primary)

                Text(summary.subheadline)
                    .font(.appBody)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                Color.accentColor.opacity(0.08),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                Text(shortLabel(for: period)).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    private func shortLabel(for period: AnalyticsPeriod) -> String {
        switch period {
        case .week:        return "7D"
        case .month:       return "30D"
        case .threeMonths: return "3M"
        case .year:        return "1Y"
        case .allTime:     return "All"
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No insights yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Start logging meals to see your patterns")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    // MARK: - Card Container

    private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .padding([.top, .horizontal])
            content()
                .padding([.bottom, .horizontal])
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private func emptyChartState(icon: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
    }

    // MARK: - Records Card

    private var recordsCard: some View {
        chartCard(title: "Your Records") {
            HStack(spacing: 0) {
                statCell(
                    icon: "flame.fill",
                    iconColor: .orange,
                    value: "\(longestStreak)",
                    label: "longest streak"
                )

                Divider().frame(height: 60)

                statCell(
                    icon: "calendar.badge.plus",
                    iconColor: .green,
                    value: "\(mostLoggedDayCount)",
                    label: "best day"
                )

                Divider().frame(height: 60)

                statCell(
                    icon: "sparkles",
                    iconColor: .purple,
                    value: "\(totalUniqueFoods)",
                    label: "unique foods"
                )
            }
            .padding(.vertical, 16)
            .padding(.top, 4)
        }
    }

    // MARK: - Chart A: Top Foods

    private var topFoodsCard: some View {
        chartCard(title: "Top Foods") {
            if topFoods.isEmpty {
                emptyChartState(icon: "fork.knife", message: "No food items logged yet")
            } else {
                Chart(topFoods) { item in
                    BarMark(
                        x: .value("Count", item.count),
                        y: .value("Food", item.item)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .chartYAxis(.automatic)
                .frame(height: CGFloat(max(180, topFoods.count * 32)))
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Chart B: Daily Activity

    private var dailyActivityCard: some View {
        chartCard(title: "Daily Activity") {
            if dailyData.allSatisfy({ $0.count == 0 }) {
                emptyChartState(icon: "calendar.badge.exclamationmark", message: "No entries in this period")
            } else {
                Chart(dailyData) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Entries", item.count)
                    )
                    .foregroundStyle(Color.accentColor)
                    AreaMark(
                        x: .value("Date", item.date),
                        yStart: .value("Low", 0),
                        yEnd: .value("High", item.count)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.1))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: xAxisStride)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 200)
                .padding(.top, 8)
            }
        }
    }

    private var xAxisStride: Int {
        switch selectedPeriod {
        case .week:        return 1
        case .month:       return 5
        case .threeMonths: return 14
        case .year:        return 60
        case .allTime:     return 60
        }
    }

    // MARK: - Chart C: Category Distribution

    private var categoryCard: some View {
        chartCard(title: "Categories") {
            if categoryData.isEmpty {
                emptyChartState(icon: "chart.pie", message: "No entries to categorise")
            } else {
                VStack(spacing: 12) {
                    ZStack {
                        Chart(categoryData) { cat in
                            SectorMark(
                                angle: .value("Count", cat.count),
                                innerRadius: .ratio(0.6)
                            )
                            .foregroundStyle(cat.category.color)
                        }
                        .frame(height: 200)

                        VStack(spacing: 2) {
                            Text("\(categoryData.reduce(0) { $0 + $1.count })")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                            Text("entries")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 8)

                    // Legend
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(categoryData) { cat in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(cat.category.color)
                                    .frame(width: 10, height: 10)
                                Text(cat.category.displayName)
                                    .font(.caption)
                                Spacer()
                                Text("\(cat.count)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
    }

    // MARK: - Chart D: Meal Timing

    private var mealTimingCard: some View {
        chartCard(title: "Meal Timing") {
            if timingData.allSatisfy({ $0.count == 0 }) {
                emptyChartState(icon: "clock", message: "No timing data available")
            } else {
                Chart(timingData) { item in
                    BarMark(
                        x: .value("Hour", item.hour),
                        y: .value("Entries", item.count)
                    )
                    .foregroundStyle(hourColor(for: item.hour))
                }
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18]) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text(hourLabel(hour))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 200)
                .padding(.top, 8)
            }
        }
    }

    private func hourColor(for hour: Int) -> Color {
        switch hour {
        case 5...10: return .orange
        case 11...14: return .green
        case 15...17: return .yellow
        case 18...22: return .indigo
        default: return .gray
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0:  return "12a"
        case 6:  return "6a"
        case 12: return "12p"
        case 18: return "6p"
        default: return "\(hour)"
        }
    }

    // MARK: - Chart E: Week vs Last Week

    private var weekTrendCard: some View {
        chartCard(title: "Week vs Last Week") {
            VStack(alignment: .leading, spacing: 8) {
                let bars: [(label: String, count: Int, color: Color)] = [
                    ("Last Week", weekTrend.lastWeek, .secondary),
                    ("This Week", weekTrend.thisWeek, .accentColor)
                ]

                Chart(bars, id: \.label) { bar in
                    BarMark(
                        x: .value("Period", bar.label),
                        y: .value("Entries", bar.count)
                    )
                    .foregroundStyle(bar.color)
                    .annotation(position: .top, alignment: .center) {
                        Text("\(bar.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: 180)
                .padding(.top, 8)

                trendLabel
                    .padding(.bottom, 4)
            }
        }
    }

    private var trendLabel: some View {
        Group {
            if weekTrend.changePercent > 0 {
                Label(
                    String(format: "↑ %.0f%% more than last week", weekTrend.changePercent),
                    systemImage: ""
                )
                .font(.caption)
                .foregroundStyle(.green)
            } else if weekTrend.changePercent < 0 {
                Label(
                    String(format: "↓ %.0f%% less than last week", abs(weekTrend.changePercent)),
                    systemImage: ""
                )
                .font(.caption)
                .foregroundStyle(.red)
            } else {
                Text("Same as last week")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Chart F: Monthly Heatmap

    private var heatmapCard: some View {
        chartCard(title: "Monthly Consistency") {
            VStack(spacing: 12) {
                // Month navigation header
                HStack {
                    Button {
                        if let prev = Calendar.current.date(byAdding: .month, value: -1, to: heatmapMonth) {
                            heatmapMonth = prev
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline)
                    }

                    Spacer()

                    Text(heatmapMonth, format: .dateTime.month(.wide).year())
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Button {
                        if let next = Calendar.current.date(byAdding: .month, value: 1, to: heatmapMonth),
                           Calendar.current.compare(next, to: Date(), toGranularity: .month) != .orderedDescending {
                            heatmapMonth = next
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.subheadline)
                    }
                    .disabled(isCurrentMonth(heatmapMonth))
                }
                .padding(.top, 8)

                // Weekday labels
                let weekdayLabels = ["M", "T", "W", "T", "F", "S", "S"]
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                    ForEach(weekdayLabels.indices, id: \.self) { i in
                        Text(weekdayLabels[i])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Day grid
                heatmapGrid
                    .padding(.bottom, 4)

                // Legend
                HStack(spacing: 12) {
                    Text("Less")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach([0, 1, 2, 3], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(heatmapColor(for: level))
                            .frame(width: 14, height: 14)
                    }
                    Text("More")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
            }
        }
    }

    private var heatmapGrid: some View {
        let calendar = Calendar.current
        let firstWeekday = heatmapFirstWeekdayOffset()
        let paddingCells = firstWeekday
        _ = paddingCells + heatmapData.count

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
            // Leading empty cells
            ForEach(0..<paddingCells, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.clear)
                    .frame(height: 28)
            }

            // Day cells
            ForEach(heatmapData) { day in
                let isFuture = calendar.compare(day.date, to: Date(), toGranularity: .day) == .orderedDescending
                RoundedRectangle(cornerRadius: 3)
                    .fill(isFuture ? Color.clear : heatmapColor(for: day.count))
                    .frame(height: 28)
                    .overlay {
                        Text("\(calendar.component(.day, from: day.date))")
                            .font(.system(size: 9))
                            .foregroundStyle(isFuture ? Color.secondary.opacity(0.3) : dayTextColor(count: day.count))
                    }
            }
        }
    }

    private func heatmapFirstWeekdayOffset() -> Int {
        let calendar = Calendar.current
        guard let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: heatmapMonth)) else {
            return 0
        }
        // ISO weekday: 2=Mon..1=Sun. We want Mon=0..Sun=6
        let isoWeekday = calendar.component(.weekday, from: firstOfMonth)
        // weekday: 1=Sun, 2=Mon..7=Sat. Convert to Mon-first (0=Mon..6=Sun)
        return (isoWeekday + 5) % 7
    }

    private func heatmapColor(for count: Int) -> Color {
        switch count {
        case 0:    return Color.gray.opacity(0.15)
        case 1:    return Color.accentColor.opacity(0.4)
        case 2:    return Color.accentColor.opacity(0.7)
        default:   return Color.accentColor
        }
    }

    private func dayTextColor(count: Int) -> Color {
        count >= 2 ? .white : .primary
    }

    private func isCurrentMonth(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
    }

    // MARK: - Chart G: Food Search

    private var foodSearchCard: some View {
        chartCard(title: "Food Search") {
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search foods…", text: $searchText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .padding(.top, 8)

                if searchText.isEmpty {
                    emptyChartState(icon: "magnifyingglass", message: "Search for a food item")
                } else if filteredSearchFoods.isEmpty {
                    emptyChartState(icon: "questionmark.circle", message: "No results for \"\(searchText)\"")
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredSearchFoods.prefix(20)) { food in
                            HStack {
                                Text(food.item.capitalized)
                                    .font(.subheadline)
                                Spacer()
                                Text("\(food.count)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor, in: Capsule())
                            }
                            .padding(.vertical, 10)

                            if food.id != filteredSearchFoods.prefix(20).last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
            }
        }
    }

    // MARK: - Chart H: Stats Card

    private var statsCard: some View {
        chartCard(title: "Your Stats") {
            HStack(spacing: 0) {
                // Current Streak
                statCell(
                    icon: "flame.fill",
                    iconColor: .orange,
                    value: "\(streakInfo.count)",
                    label: "day streak"
                )

                Divider().frame(height: 60)

                // Consistency ring
                consistencyCell

                Divider().frame(height: 60)

                // Total entries
                statCell(
                    icon: "list.bullet",
                    iconColor: .accentColor,
                    value: "\(totalEntriesInPeriod)",
                    label: "entries"
                )
            }
            .padding(.vertical, 16)
            .padding(.top, 4)
        }
    }

    private func statCell(icon: String, iconColor: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var consistencyCell: some View {
        let fraction = min(consistencyFraction, 1.0)
        let pct = Int(fraction * 100)

        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                    .frame(width: 48, height: 48)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-90))
                Text("\(pct)%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            Text("consistency")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    InsightsView(entries: [])
}
