//
//  FoodItemTimelineView.swift
//  FoodLogger
//
//  Drill-down view showing when a specific food item was logged —
//  occurrence timeline, day-of-week pattern, and time-of-day distribution.
//

import SwiftUI
import Charts

struct FoodItemTimelineView: View {
    let term: String
    let entries: [FoodEntry]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod: AnalyticsPeriod = .month

    private let service = InsightsService()

    // MARK: - Derived data

    private var matchedEntries: [FoodEntry] {
        service.entriesMatching(term: term, from: entries)
    }

    private var totalCount: Int { matchedEntries.count }

    private var lastSeenText: String {
        guard let last = matchedEntries.max(by: { $0.date < $1.date }) else { return "Never" }
        let days = Calendar.current.dateComponents([.day], from: last.date, to: Calendar.current.startOfDay(for: Date())).day ?? 0
        switch days {
        case 0:  return "Today"
        case 1:  return "Yesterday"
        default: return "\(days) days ago"
        }
    }

    private var periodCount: Int {
        service.filterByPeriod(matchedEntries, period: selectedPeriod).count
    }

    private var dailyData: [DailyCount] {
        service.itemDailyCounts(for: term, from: entries, period: selectedPeriod)
    }

    private var weekdayData: [WeekdayCount] {
        service.itemWeekdayPattern(for: term, from: entries, period: selectedPeriod)
    }

    private var timingData: [HourCount] {
        service.itemMealTiming(for: term, from: entries, period: selectedPeriod)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    headerStats
                        .padding(.top, 8)

                    periodPicker
                        .padding(.horizontal, 16)

                    occurrenceCard
                    weekdayCard
                    timingCard
                }
                .padding(.bottom, 32)
            }
            .background(Color.brandVoid)
            .navigationTitle(term.capitalized)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.brandVoid, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(Color.brandAccent)
                }
            }
        }
    }

    // MARK: - Header Stats

    private var headerStats: some View {
        HStack(spacing: 0) {
            statCell(value: "\(totalCount)",  label: "times total",  icon: "chart.bar.fill",        iconColor: Color.brandAccent)
            Divider().frame(height: 56)
            statCell(value: lastSeenText,     label: "last eaten",   icon: "calendar",              iconColor: Color.brandWarm)
            Divider().frame(height: 56)
            statCell(value: "\(periodCount)", label: "in period",    icon: "clock.arrow.circlepath", iconColor: Color.brandSuccess)
        }
        .padding(.vertical, 16)
        .background {
            ZStack {
                Color.brandVoid
                Color.brandSurface.opacity(0.03)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.brandSurface.opacity(0.07), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func statCell(value: String, label: String, icon: String, iconColor: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
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

    // MARK: - Occurrence Chart

    private var occurrenceCard: some View {
        chartCard(title: "When You Had It") {
            let hasData = dailyData.contains { $0.count > 0 }
            if !hasData {
                emptyChartState(icon: "calendar.badge.exclamationmark", message: "No occurrences in this period")
            } else {
                Chart(dailyData) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Times", item.count)
                    )
                    .foregroundStyle(Color.brandAccent)
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: xAxisStride)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 180)
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

    // MARK: - Day-of-Week Chart

    private var weekdayCard: some View {
        chartCard(title: "Day of Week Pattern") {
            let hasData = weekdayData.contains { $0.count > 0 }
            if !hasData {
                emptyChartState(icon: "calendar", message: "Not enough data yet")
            } else {
                Chart(weekdayData) { item in
                    BarMark(
                        x: .value("Day", item.shortLabel),
                        y: .value("Times", item.count)
                    )
                    .foregroundStyle(Color.brandWarm.opacity(0.85))
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 150)
                .padding(.top, 8)
            }
        }
    }

    // MARK: - Time of Day Chart

    private var timingCard: some View {
        chartCard(title: "Time of Day") {
            let hasData = timingData.contains { $0.count > 0 }
            if !hasData {
                emptyChartState(icon: "clock", message: "Not enough data yet")
            } else {
                Chart(timingData) { item in
                    BarMark(
                        x: .value("Hour", item.hour),
                        y: .value("Times", item.count)
                    )
                    .foregroundStyle(hourColor(for: item.hour))
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18]) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text(hourLabel(hour)).font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 150)
                .padding(.top, 8)
            }
        }
    }

    private func hourColor(for hour: Int) -> Color {
        switch hour {
        case 5...10:  return .orange
        case 11...14: return .green
        case 15...17: return .yellow
        case 18...22: return .indigo
        default:      return .gray
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

    // MARK: - Card helpers (mirrors InsightsView style)

    private func chartCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .kerning(1.0)
                .foregroundStyle(Color.brandWarm.opacity(0.7))
                .padding([.top, .horizontal])
                .padding(.bottom, 4)
            content()
                .padding([.bottom, .horizontal])
        }
        .background {
            ZStack {
                Color.brandVoid
                Color.brandSurface.opacity(0.03)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.brandSurface.opacity(0.07), lineWidth: 1)
        )
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
        .frame(height: 120)
    }
}
