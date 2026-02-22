//
//  InsightsService.swift
//  FoodLogger
//
//  Analytics service providing typed insight structs over FoodEntry collections.
//

import Foundation

// MARK: - Period

enum AnalyticsPeriod: String, CaseIterable {
    case week        = "Week"
    case month       = "Month"
    case threeMonths = "3 Months"
    case year        = "Year"
    case allTime     = "All Time"
}

// MARK: - Result types

struct FoodItemFrequency: Identifiable {
    var id: String { item }
    let item: String
    let count: Int
}

struct DailyCount: Identifiable {
    var id: Date { date }
    let date: Date
    let count: Int
}

struct CategoryCount: Identifiable {
    var id: String { category.rawValue }
    let category: MealCategory
    let count: Int
    let percentage: Double
}

struct InputTypeCount: Identifiable {
    var id: String { inputType.rawValue }
    let inputType: InputType
    let count: Int
    let percentage: Double
}

struct HourCount: Identifiable {
    var id: Int { hour }
    let hour: Int
    let count: Int
}

struct WeekComparison {
    let thisWeek: Int
    let lastWeek: Int
    let changePercent: Double
}

struct DayActivity: Identifiable {
    var id: Date { date }
    let date: Date
    let count: Int
}

struct ItemPair: Identifiable {
    var id: String { "\(item1)|\(item2)" }
    let item1: String
    let item2: String
    let count: Int
}

// MARK: - Service

@MainActor final class InsightsService {

    // MARK: Stopwords

    private static let stopwords: Set<String> = [
        "a", "the", "and", "with", "of", "in", "for", "had", "ate", "some", "my", "an"
    ]

    // MARK: - Public API

    func topItems(from entries: [FoodEntry], period: AnalyticsPeriod, limit: Int = 10) -> [FoodItemFrequency] {
        let filtered = filterByPeriod(entries, period: period)
        var freq: [String: Int] = [:]

        for entry in filtered {
            let words = tokenise(entry.processedDescription)
            for word in words {
                freq[word, default: 0] += 1
            }
        }

        return freq
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { FoodItemFrequency(item: $0.key, count: $0.value) }
    }

    func dailyCounts(from entries: [FoodEntry], period: AnalyticsPeriod) -> [DailyCount] {
        let filtered = filterByPeriod(entries, period: period)
        let calendar = Calendar.current

        // Build a map: startOfDay -> count
        var countMap: [Date: Int] = [:]
        for entry in filtered {
            let day = calendar.startOfDay(for: entry.date)
            countMap[day, default: 0] += 1
        }

        // Determine the date range to fill
        let (startDate, endDate) = periodBounds(for: period)
        guard let start = startDate else {
            // allTime: just return what we have, sorted
            return countMap
                .sorted { $0.key < $1.key }
                .map { DailyCount(date: $0.key, count: $0.value) }
        }

        var results: [DailyCount] = []
        var current = calendar.startOfDay(for: start)
        let end = calendar.startOfDay(for: endDate)

        while current <= end {
            results.append(DailyCount(date: current, count: countMap[current] ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return results
    }

    func categoryDistribution(from entries: [FoodEntry], period: AnalyticsPeriod) -> [CategoryCount] {
        let filtered = filterByPeriod(entries, period: period)
        let total = filtered.count
        var freq: [MealCategory: Int] = [:]
        for entry in filtered {
            if let cat = entry.category {
                freq[cat, default: 0] += 1
            }
        }
        return MealCategory.allCases.compactMap { cat in
            let count = freq[cat] ?? 0
            guard count > 0 else { return nil }
            let pct = total > 0 ? Double(count) / Double(total) * 100.0 : 0.0
            return CategoryCount(category: cat, count: count, percentage: pct)
        }
        .sorted { $0.count > $1.count }
    }

    func inputTypeBreakdown(from entries: [FoodEntry], period: AnalyticsPeriod) -> [InputTypeCount] {
        let filtered = filterByPeriod(entries, period: period)
        let total = filtered.count
        var freq: [InputType: Int] = [:]
        for entry in filtered {
            freq[entry.inputType, default: 0] += 1
        }
        return InputType.allCases.compactMap { type in
            let count = freq[type] ?? 0
            guard count > 0 else { return nil }
            let pct = total > 0 ? Double(count) / Double(total) * 100.0 : 0.0
            return InputTypeCount(inputType: type, count: count, percentage: pct)
        }
        .sorted { $0.count > $1.count }
    }

    func mealTiming(from entries: [FoodEntry], period: AnalyticsPeriod) -> [HourCount] {
        let filtered = filterByPeriod(entries, period: period)
        var freq: [Int: Int] = [:]
        let calendar = Calendar.current
        for entry in filtered {
            let hour = calendar.component(.hour, from: entry.createdAt)
            freq[hour, default: 0] += 1
        }
        return (0..<24).map { hour in
            HourCount(hour: hour, count: freq[hour] ?? 0)
        }
    }

    func weekOverWeekTrend(from entries: [FoodEntry]) -> WeekComparison {
        let now = Date()
        let calendar = Calendar.current
        guard let sevenDaysAgo  = calendar.date(byAdding: .day, value: -7,  to: now),
              let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now) else {
            return WeekComparison(thisWeek: 0, lastWeek: 0, changePercent: 0)
        }

        let thisWeek = entries.filter { $0.createdAt >= sevenDaysAgo && $0.createdAt <= now }.count
        let lastWeek = entries.filter { $0.createdAt >= fourteenDaysAgo && $0.createdAt < sevenDaysAgo }.count

        let changePercent: Double
        if lastWeek == 0 {
            changePercent = thisWeek > 0 ? 100.0 : 0.0
        } else {
            changePercent = Double(thisWeek - lastWeek) / Double(lastWeek) * 100.0
        }

        return WeekComparison(thisWeek: thisWeek, lastWeek: lastWeek, changePercent: changePercent)
    }

    func monthlyHeatmap(from entries: [FoodEntry], month: Date) -> [DayActivity] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }

        // Build count map from entries that fall in this month
        var countMap: [Date: Int] = [:]
        for entry in entries {
            let entryDay = calendar.startOfDay(for: entry.date)
            let comps = calendar.dateComponents([.year, .month], from: entryDay)
            let monthComps = calendar.dateComponents([.year, .month], from: month)
            if comps.year == monthComps.year && comps.month == monthComps.month {
                countMap[entryDay, default: 0] += 1
            }
        }

        return range.compactMap { dayOffset -> DayActivity? in
            guard let date = calendar.date(byAdding: .day, value: dayOffset - 1, to: firstOfMonth) else {
                return nil
            }
            let day = calendar.startOfDay(for: date)
            return DayActivity(date: day, count: countMap[day] ?? 0)
        }
    }

    func coOccurrence(from entries: [FoodEntry], period: AnalyticsPeriod) -> [ItemPair] {
        let filtered = filterByPeriod(entries, period: period)
        let calendar = Calendar.current

        // Group word sets by day
        var dayItems: [Date: Set<String>] = [:]
        for entry in filtered {
            let day = calendar.startOfDay(for: entry.date)
            let words = Set(tokenise(entry.processedDescription))
            dayItems[day, default: []].formUnion(words)
        }

        // Count pairs
        var pairCount: [String: (item1: String, item2: String, count: Int)] = [:]
        for (_, items) in dayItems {
            let sorted = items.sorted()
            for i in 0..<sorted.count {
                for j in (i + 1)..<sorted.count {
                    let key = "\(sorted[i])|\(sorted[j])"
                    if let existing = pairCount[key] {
                        pairCount[key] = (existing.item1, existing.item2, existing.count + 1)
                    } else {
                        pairCount[key] = (sorted[i], sorted[j], 1)
                    }
                }
            }
        }

        return pairCount.values
            .sorted { $0.count > $1.count }
            .prefix(10)
            .map { ItemPair(item1: $0.item1, item2: $0.item2, count: $0.count) }
    }

    // MARK: - Private helpers

    func filterByPeriod(_ entries: [FoodEntry], period: AnalyticsPeriod) -> [FoodEntry] {
        guard period != .allTime else { return entries }
        let days: Int
        switch period {
        case .week:        days = 7
        case .month:       days = 30
        case .threeMonths: days = 90
        case .year:        days = 365
        case .allTime:     return entries
        }
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return entries.filter { $0.createdAt >= cutoff }
    }

    private func periodBounds(for period: AnalyticsPeriod) -> (start: Date?, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        switch period {
        case .allTime:
            return (nil, now)
        case .week:
            return (calendar.date(byAdding: .day, value: -7, to: now), now)
        case .month:
            return (calendar.date(byAdding: .day, value: -30, to: now), now)
        case .threeMonths:
            return (calendar.date(byAdding: .day, value: -90, to: now), now)
        case .year:
            return (calendar.date(byAdding: .day, value: -365, to: now), now)
        }
    }

    private func tokenise(_ text: String) -> [String] {
        // Split on whitespace and common punctuation, lowercase, strip stopwords
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        return text
            .lowercased()
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !Self.stopwords.contains($0) && $0.count > 1 }
    }
}
