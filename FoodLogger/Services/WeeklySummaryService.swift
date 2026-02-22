import Foundation

// MARK: - WeeklySummary

struct WeeklySummary {
    let weekStartDate: Date        // Monday of the week
    let totalEntries: Int
    let topFoodItem: String?       // most frequent non-stopword token
    let topFoodCount: Int
    let topCategory: MealCategory?
    let bestDay: Date?             // day with most entries (startOfDay)
    let currentStreak: Int
    let longestStreak: Int         // longest consecutive run in the week
    let uniqueFoodsCount: Int      // count of distinct non-stopword tokens
    let vsLastWeek: Int            // thisWeek - lastWeek (positive = more)
    let mostActiveHour: Int?       // 0-23 hour with most entries
    let headline: String
    let subheadline: String
    let missedDays: Int            // days Mon-Sun with zero entries
    let categoryBreakdown: [MealCategory: Int]  // count per category for this week
    let dailyEntryCounts: [Date: Int]           // startOfDay -> count for Mon-Sun
}

// MARK: - Service

@MainActor final class WeeklySummaryService {

    // Stopwords matching InsightsService
    private static let stopwords: Set<String> = [
        "a", "the", "and", "with", "of", "in", "for", "had", "ate", "some", "my", "an"
    ]

    // MARK: - Public API

    func generateSummary(from entries: [FoodEntry]) -> WeeklySummary {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find Monday of current week (ISO: weekday 2 = Monday)
        let weekday = calendar.component(.weekday, from: today)
        // Calendar.current may have firstWeekday = 1 (Sunday). Monday offset:
        let daysFromMonday = (weekday + 5) % 7   // Sun=0→6, Mon=1→0, Tue=2→1, ...
        let weekStart = calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart)!
        let lastWeekEnd = weekStart

        // Filter to this week and last week
        let thisWeekEntries = entries.filter { $0.date >= weekStart && $0.date < weekEnd }
        let lastWeekEntries = entries.filter { $0.date >= lastWeekStart && $0.date < lastWeekEnd }

        // Daily counts for Mon-Sun
        var dailyEntryCounts: [Date: Int] = [:]
        for dayOffset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            dailyEntryCounts[day] = 0
        }
        for entry in thisWeekEntries {
            let day = calendar.startOfDay(for: entry.date)
            dailyEntryCounts[day, default: 0] += 1
        }

        // Missed days
        let missedDays = dailyEntryCounts.values.filter { $0 == 0 }.count

        // Best day
        let bestDay = dailyEntryCounts.max(by: { $0.value < $1.value })?.key

        // Top food item (most frequent non-stopword token)
        var tokenFreq: [String: Int] = [:]
        for entry in thisWeekEntries {
            for token in tokenise(entry.processedDescription) {
                tokenFreq[token, default: 0] += 1
            }
        }
        let topFoodEntry = tokenFreq.max(by: { $0.value < $1.value })
        let topFoodItem = topFoodEntry?.key
        let topFoodCount = topFoodEntry?.value ?? 0
        let uniqueFoodsCount = tokenFreq.keys.count

        // Top category
        var catFreq: [MealCategory: Int] = [:]
        for entry in thisWeekEntries {
            if let cat = entry.category {
                catFreq[cat, default: 0] += 1
            }
        }
        let topCategory = catFreq.max(by: { $0.value < $1.value })?.key
        let categoryBreakdown = catFreq

        // Most active hour
        var hourFreq: [Int: Int] = [:]
        for entry in thisWeekEntries {
            let hour = calendar.component(.hour, from: entry.createdAt)
            hourFreq[hour, default: 0] += 1
        }
        let mostActiveHour = hourFreq.max(by: { $0.value < $1.value })?.key

        // Streak: use StreakService pattern — count consecutive days with entries ending at today
        let streakService = StreakService()
        let streakInfo = streakService.compute(from: entries)
        let currentStreak = streakInfo.count

        // Longest streak within the week
        var longestStreak = 0
        var currentRun = 0
        for dayOffset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            if (dailyEntryCounts[day] ?? 0) > 0 {
                currentRun += 1
                longestStreak = max(longestStreak, currentRun)
            } else {
                currentRun = 0
            }
        }

        // vs last week
        let vsLastWeek = thisWeekEntries.count - lastWeekEntries.count

        // Build provisional summary (without headline/subheadline)
        let provisional = WeeklySummary(
            weekStartDate: weekStart,
            totalEntries: thisWeekEntries.count,
            topFoodItem: topFoodItem,
            topFoodCount: topFoodCount,
            topCategory: topCategory,
            bestDay: bestDay,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            uniqueFoodsCount: uniqueFoodsCount,
            vsLastWeek: vsLastWeek,
            mostActiveHour: mostActiveHour,
            headline: "",
            subheadline: "",
            missedDays: missedDays,
            categoryBreakdown: categoryBreakdown,
            dailyEntryCounts: dailyEntryCounts
        )

        let headline = generateHeadline(from: provisional)
        let subheadline = generateSubheadline(from: provisional)

        return WeeklySummary(
            weekStartDate: weekStart,
            totalEntries: thisWeekEntries.count,
            topFoodItem: topFoodItem,
            topFoodCount: topFoodCount,
            topCategory: topCategory,
            bestDay: bestDay,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            uniqueFoodsCount: uniqueFoodsCount,
            vsLastWeek: vsLastWeek,
            mostActiveHour: mostActiveHour,
            headline: headline,
            subheadline: subheadline,
            missedDays: missedDays,
            categoryBreakdown: categoryBreakdown,
            dailyEntryCounts: dailyEntryCounts
        )
    }

    // MARK: - Headline type enum (internal, used to avoid repeating the same stat in subheadline)

    enum HeadlineType {
        case streak, topFood, improvement, perfect, `default`
    }

    func headlineType(for summary: WeeklySummary) -> HeadlineType {
        if summary.currentStreak > 7 { return .streak }
        if summary.topFoodCount >= 3 { return .topFood }
        if summary.vsLastWeek > 3 { return .improvement }
        if summary.missedDays == 0 { return .perfect }
        return .default
    }

    func generateHeadline(from summary: WeeklySummary) -> String {
        switch headlineType(for: summary) {
        case .streak:
            return "\(summary.currentStreak) days and counting 🔥"
        case .topFood:
            let food = summary.topFoodItem?.capitalized ?? "That dish"
            return "\(food) week it is 🍛 — you had it \(summary.topFoodCount) times"
        case .improvement:
            return "Your most active week in a while 📈"
        case .perfect:
            return "Perfect week — not a single day missed ✨"
        case .default:
            let catName = summary.topCategory?.displayName ?? "your meals"
            return "\(summary.totalEntries) meals logged. \(catName) was your go-to."
        }
    }

    func generateSubheadline(from summary: WeeklySummary) -> String {
        switch headlineType(for: summary) {
        case .streak:
            // Lead with food or improvement
            if summary.topFoodCount >= 2, let food = summary.topFoodItem {
                return "You had \(food.lowercased()) \(summary.topFoodCount) times — a clear favourite this week."
            }
            return "You logged \(summary.totalEntries) meals across \(7 - summary.missedDays) days."
        case .topFood:
            // Lead with streak or day count
            if summary.currentStreak > 1 {
                return "You're on a \(summary.currentStreak)-day logging streak. Keep it up!"
            }
            return "You tried \(summary.uniqueFoodsCount) different foods this week."
        case .improvement:
            // Lead with consistency
            if summary.missedDays == 0 {
                return "You logged every single day — a perfect week."
            }
            return "You logged \(7 - summary.missedDays) out of 7 days."
        case .perfect:
            // Lead with streak or food
            if summary.currentStreak > 3 {
                return "You're on a \(summary.currentStreak)-day streak — amazing consistency."
            }
            if let food = summary.topFoodItem, summary.topFoodCount >= 2 {
                return "\(food.capitalized) was your most-logged food this week."
            }
            return "You logged \(summary.totalEntries) meals total. Well done."
        case .default:
            if summary.currentStreak > 1 {
                return "You're on a \(summary.currentStreak)-day streak. Keep logging!"
            }
            if summary.uniqueFoodsCount > 5 {
                return "You explored \(summary.uniqueFoodsCount) different foods this week."
            }
            return "Log every day and you'll build a great streak."
        }
    }

    // MARK: - Tokeniser

    private func tokenise(_ text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !Self.stopwords.contains($0) && $0.count > 2 }
    }
}
