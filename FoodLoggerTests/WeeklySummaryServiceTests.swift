import Testing
import SwiftData
import Foundation
@testable import FoodLogger

@MainActor
@Suite("WeeklySummaryService Tests")
struct WeeklySummaryServiceTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([FoodEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeEntry(
        context: ModelContext,
        description: String,
        daysAgo: Int = 0,
        category: MealCategory? = .lunch,
        createdHour: Int = 12
    ) -> FoodEntry {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = createdHour
        let createdAt = calendar.date(from: components) ?? date
        let entry = FoodEntry(
            date: date,
            rawInput: description,
            inputType: .text,
            processedDescription: description,
            createdAt: createdAt,
            category: category
        )
        context.insert(entry)
        return entry
    }

    // Returns Monday of current week
    private func thisMonday() -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: today)!
    }

    // MARK: - Tests

    @Test("Zero entries returns safe defaults — no crash")
    func testZeroEntries() throws {
        let service = WeeklySummaryService()
        let summary = service.generateSummary(from: [])

        #expect(summary.totalEntries == 0)
        #expect(summary.topFoodItem == nil)
        #expect(summary.topFoodCount == 0)
        #expect(summary.topCategory == nil)
        #expect(summary.missedDays == 7)
        #expect(summary.uniqueFoodsCount == 0)
        #expect(!summary.headline.isEmpty)
        #expect(!summary.subheadline.isEmpty)
    }

    @Test("Single entry returns valid summary")
    func testSingleEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let entry = makeEntry(context: context, description: "chicken rice bowl", daysAgo: 0)
        let service = WeeklySummaryService()
        let summary = service.generateSummary(from: [entry])

        #expect(summary.totalEntries == 1)
        #expect(summary.missedDays == 6)
        #expect(!summary.headline.isEmpty)
    }

    @Test("totalEntries counts only this week's entries")
    func testTotalEntriesCountsThisWeek() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let _ = makeEntry(context: context, description: "pasta carbonara", daysAgo: 0)
        let _ = makeEntry(context: context, description: "grilled salmon", daysAgo: 1)
        let _ = makeEntry(context: context, description: "chicken salad", daysAgo: 2)
        let _ = makeEntry(context: context, description: "old pizza", daysAgo: 8)
        let _ = makeEntry(context: context, description: "old burger", daysAgo: 9)

        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let service = WeeklySummaryService()
        let summary = service.generateSummary(from: entries)
        // Only entries within Monday-Sunday of this week count
        // daysAgo 0, 1, 2 may or may not all fall in current week depending on weekday
        // But entries daysAgo 8 and 9 are definitely last week or earlier
        #expect(summary.totalEntries <= 3)
        #expect(summary.totalEntries >= 1) // at least today's entry
    }

    @Test("vsLastWeek is positive when this week has more entries")
    func testVsLastWeekPositive() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        // 3 this week
        let _ = makeEntry(context: context, description: "breakfast toast", daysAgo: 0)
        let _ = makeEntry(context: context, description: "lunch salad", daysAgo: 1)
        let _ = makeEntry(context: context, description: "dinner soup", daysAgo: 2)
        // 1 last week
        let _ = makeEntry(context: context, description: "old pasta", daysAgo: 8)
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let service = WeeklySummaryService()
        let summary = service.generateSummary(from: entries)
        #expect(summary.vsLastWeek > 0)
    }

    @Test("vsLastWeek is negative when this week has fewer entries")
    func testVsLastWeekNegative() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        // 1 this week
        let _ = makeEntry(context: context, description: "breakfast toast", daysAgo: 0)
        // 3 last week
        let _ = makeEntry(context: context, description: "old pasta", daysAgo: 8)
        let _ = makeEntry(context: context, description: "old salad", daysAgo: 9)
        let _ = makeEntry(context: context, description: "old soup", daysAgo: 10)
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let service = WeeklySummaryService()
        let summary = service.generateSummary(from: entries)
        #expect(summary.vsLastWeek < 0)
    }

    @Test("bestDay is the day with the most entries")
    func testBestDay() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        // 1 entry today, 3 entries 1 day ago, 1 entry 2 days ago
        let _ = makeEntry(context: context, description: "breakfast", daysAgo: 0)
        let _ = makeEntry(context: context, description: "lunch burger", daysAgo: 1)
        let _ = makeEntry(context: context, description: "dinner steak", daysAgo: 1)
        let _ = makeEntry(context: context, description: "snack chips", daysAgo: 1)
        let _ = makeEntry(context: context, description: "dinner pasta", daysAgo: 2)
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let service = WeeklySummaryService()
        let summary = service.generateSummary(from: entries)
        let calendar = Calendar.current
        let expectedBestDay = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
        #expect(summary.bestDay == expectedBestDay)
    }

    @Test("uniqueFoodsCount excludes stopwords and short tokens")
    func testUniqueFoodsCountExcludesStopwords() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        // "had" and "the" are stopwords; "pasta", "rice", "bowl" are valid tokens (>2 chars, not stopword)
        let _ = makeEntry(context: context, description: "had the pasta", daysAgo: 0)
        let _ = makeEntry(context: context, description: "rice bowl", daysAgo: 1)
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let service = WeeklySummaryService()
        let summary = service.generateSummary(from: entries)
        // Tokens: "pasta", "rice", "bowl" = 3 unique (stopwords "had", "the" excluded)
        #expect(summary.uniqueFoodsCount == 3)
    }

    @Test("topFoodItem is most frequent non-stopword token")
    func testTopFoodItem() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let _ = makeEntry(context: context, description: "chicken rice", daysAgo: 0)
        let _ = makeEntry(context: context, description: "chicken curry", daysAgo: 1)
        let _ = makeEntry(context: context, description: "chicken soup", daysAgo: 2)
        let _ = makeEntry(context: context, description: "pasta salad", daysAgo: 3)
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let service = WeeklySummaryService()
        let summary = service.generateSummary(from: entries)
        #expect(summary.topFoodItem == "chicken")
        #expect(summary.topFoodCount == 3)
    }

    @Test("Headline leads with streak when streak > 7")
    func testHeadlineStreakWhenStreakOver7() throws {
        let service = WeeklySummaryService()
        let summary = WeeklySummary(
            weekStartDate: thisMonday(),
            totalEntries: 10,
            topFoodItem: nil,
            topFoodCount: 0,
            topCategory: .lunch,
            bestDay: nil,
            currentStreak: 10,
            longestStreak: 7,
            uniqueFoodsCount: 5,
            vsLastWeek: 0,
            mostActiveHour: nil,
            headline: "",
            subheadline: "",
            missedDays: 0,
            categoryBreakdown: [:],
            dailyEntryCounts: [:]
        )
        let headline = service.generateHeadline(from: summary)
        // Expected: "10 days and counting 🔥"
        #expect(headline.contains("10"))
        #expect(headline.contains("🔥"))
        #expect(service.headlineType(for: summary) == .streak)
    }

    @Test("Headline leads with food when top food appears 3+ times")
    func testHeadlineTopFoodWhen3OrMore() throws {
        let service = WeeklySummaryService()
        let summary = WeeklySummary(
            weekStartDate: thisMonday(),
            totalEntries: 8,
            topFoodItem: "biryani",
            topFoodCount: 3,
            topCategory: .dinner,
            bestDay: nil,
            currentStreak: 5,
            longestStreak: 5,
            uniqueFoodsCount: 6,
            vsLastWeek: 1,
            mostActiveHour: 13,
            headline: "",
            subheadline: "",
            missedDays: 2,
            categoryBreakdown: [:],
            dailyEntryCounts: [:]
        )
        let headline = service.generateHeadline(from: summary)
        // Expected: "Biryani week it is 🍛 — you had it 3 times"
        #expect(headline.lowercased().contains("biryani"))
        #expect(headline.contains("3"))
        #expect(service.headlineType(for: summary) == .topFood)
    }

    @Test("Headline leads with improvement when vsLastWeek > 3")
    func testHeadlineImprovementWhenVsLastWeekOver3() throws {
        let service = WeeklySummaryService()
        let summary = WeeklySummary(
            weekStartDate: thisMonday(),
            totalEntries: 12,
            topFoodItem: "pasta",
            topFoodCount: 2,
            topCategory: .dinner,
            bestDay: nil,
            currentStreak: 4,
            longestStreak: 4,
            uniqueFoodsCount: 8,
            vsLastWeek: 5,
            mostActiveHour: 12,
            headline: "",
            subheadline: "",
            missedDays: 1,
            categoryBreakdown: [:],
            dailyEntryCounts: [:]
        )
        let headline = service.generateHeadline(from: summary)
        // Expected: "Your most active week in a while 📈"
        #expect(headline.contains("📈"))
        #expect(service.headlineType(for: summary) == .improvement)
    }

    @Test("Headline leads with perfect week when missedDays == 0")
    func testHeadlinePerfectWhenNoMissedDays() throws {
        let service = WeeklySummaryService()
        let summary = WeeklySummary(
            weekStartDate: thisMonday(),
            totalEntries: 14,
            topFoodItem: "salad",
            topFoodCount: 2,
            topCategory: .lunch,
            bestDay: nil,
            currentStreak: 7,
            longestStreak: 7,
            uniqueFoodsCount: 10,
            vsLastWeek: 2,
            mostActiveHour: 12,
            headline: "",
            subheadline: "",
            missedDays: 0,
            categoryBreakdown: [:],
            dailyEntryCounts: [:]
        )
        let headline = service.generateHeadline(from: summary)
        // Expected: "Perfect week — not a single day missed ✨"
        #expect(headline.contains("✨") || headline.lowercased().contains("perfect"))
        #expect(service.headlineType(for: summary) == .perfect)
    }

    @Test("Default headline uses totalEntries and category when no special condition")
    func testHeadlineDefault() throws {
        let service = WeeklySummaryService()
        let summary = WeeklySummary(
            weekStartDate: thisMonday(),
            totalEntries: 5,
            topFoodItem: "pasta",
            topFoodCount: 2,
            topCategory: .dinner,
            bestDay: nil,
            currentStreak: 3,
            longestStreak: 3,
            uniqueFoodsCount: 4,
            vsLastWeek: -1,
            mostActiveHour: nil,
            headline: "",
            subheadline: "",
            missedDays: 3,
            categoryBreakdown: [:],
            dailyEntryCounts: [:]
        )
        let headline = service.generateHeadline(from: summary)
        // Expected: "5 meals logged. Dinner was your go-to."
        #expect(headline.contains("5"))
        #expect(service.headlineType(for: summary) == .default)
    }

    @Test("Subheadline is different stat from headline")
    func testSubheadlineDiffersFromHeadline() throws {
        let service = WeeklySummaryService()
        let summary = WeeklySummary(
            weekStartDate: thisMonday(),
            totalEntries: 10,
            topFoodItem: "chicken",
            topFoodCount: 3,
            topCategory: .lunch,
            bestDay: nil,
            currentStreak: 4,
            longestStreak: 4,
            uniqueFoodsCount: 6,
            vsLastWeek: 1,
            mostActiveHour: 12,
            headline: "",
            subheadline: "",
            missedDays: 2,
            categoryBreakdown: [:],
            dailyEntryCounts: [:]
        )
        let headline = service.generateHeadline(from: summary)
        let subheadline = service.generateSubheadline(from: summary)
        #expect(headline != subheadline)
        #expect(!subheadline.isEmpty)
    }

    @Test("missedDays is 7 for empty week")
    func testMissedDaysFullWeekEmpty() throws {
        let service = WeeklySummaryService()
        let summary = service.generateSummary(from: [])
        #expect(summary.missedDays == 7)
    }

    @Test("missedDays is less than 7 when at least today has an entry")
    func testMissedDaysLessThan7ForTodayEntry() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let _ = makeEntry(context: context, description: "daily meal today", daysAgo: 0)
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let service = WeeklySummaryService()
        let summary = service.generateSummary(from: entries)
        #expect(summary.missedDays < 7)
    }

    @Test("topCategory matches entry with highest category count")
    func testTopCategory() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let _ = makeEntry(context: context, description: "breakfast eggs", daysAgo: 0, category: .breakfast)
        let _ = makeEntry(context: context, description: "lunch salad", daysAgo: 1, category: .dinner)
        let _ = makeEntry(context: context, description: "dinner steak", daysAgo: 2, category: .dinner)
        let _ = makeEntry(context: context, description: "dinner pasta", daysAgo: 3, category: .dinner)
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let service = WeeklySummaryService()
        let summary = service.generateSummary(from: entries)
        #expect(summary.topCategory == .dinner)
    }

    @Test("generateSummary with all entries outside this week gives zero count")
    func testAllEntriesOutsideThisWeek() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        // Add entries 8-14 days ago (last week + 1)
        for i in 8..<15 {
            let _ = makeEntry(context: context, description: "old food \(i)", daysAgo: i)
        }
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let service = WeeklySummaryService()
        let summary = service.generateSummary(from: entries)
        #expect(summary.totalEntries == 0)
        #expect(summary.missedDays == 7)
    }

    @Test("headlineType returns streak for streak > 7")
    func testHeadlineTypeStreak() throws {
        let service = WeeklySummaryService()
        let summary = WeeklySummary(
            weekStartDate: thisMonday(),
            totalEntries: 15,
            topFoodItem: "rice",
            topFoodCount: 4,
            topCategory: .lunch,
            bestDay: nil,
            currentStreak: 8,
            longestStreak: 7,
            uniqueFoodsCount: 5,
            vsLastWeek: 5,
            mostActiveHour: nil,
            headline: "",
            subheadline: "",
            missedDays: 0,
            categoryBreakdown: [:],
            dailyEntryCounts: [:]
        )
        // streak > 7 wins even when topFood >= 3, vsLastWeek > 3, and missedDays == 0
        #expect(service.headlineType(for: summary) == .streak)
    }

    @Test("headlineType returns topFood when streak <= 7 and topFoodCount >= 3")
    func testHeadlineTypeTopFood() throws {
        let service = WeeklySummaryService()
        let summary = WeeklySummary(
            weekStartDate: thisMonday(),
            totalEntries: 10,
            topFoodItem: "pizza",
            topFoodCount: 3,
            topCategory: .dinner,
            bestDay: nil,
            currentStreak: 7,
            longestStreak: 7,
            uniqueFoodsCount: 6,
            vsLastWeek: 5,
            mostActiveHour: nil,
            headline: "",
            subheadline: "",
            missedDays: 0,
            categoryBreakdown: [:],
            dailyEntryCounts: [:]
        )
        // streak == 7 (not > 7), topFoodCount == 3 (>= 3) → topFood
        #expect(service.headlineType(for: summary) == .topFood)
    }

    @Test("headlineType returns improvement when vsLastWeek > 3 and no higher priority")
    func testHeadlineTypeImprovement() throws {
        let service = WeeklySummaryService()
        let summary = WeeklySummary(
            weekStartDate: thisMonday(),
            totalEntries: 10,
            topFoodItem: "pasta",
            topFoodCount: 2,
            topCategory: .dinner,
            bestDay: nil,
            currentStreak: 5,
            longestStreak: 5,
            uniqueFoodsCount: 6,
            vsLastWeek: 4,
            mostActiveHour: nil,
            headline: "",
            subheadline: "",
            missedDays: 2,
            categoryBreakdown: [:],
            dailyEntryCounts: [:]
        )
        #expect(service.headlineType(for: summary) == .improvement)
    }

    @Test("headlineType returns perfect when missedDays == 0 and no higher priority")
    func testHeadlineTypePerfect() throws {
        let service = WeeklySummaryService()
        let summary = WeeklySummary(
            weekStartDate: thisMonday(),
            totalEntries: 7,
            topFoodItem: "salad",
            topFoodCount: 2,
            topCategory: .lunch,
            bestDay: nil,
            currentStreak: 7,
            longestStreak: 7,
            uniqueFoodsCount: 5,
            vsLastWeek: 1,
            mostActiveHour: nil,
            headline: "",
            subheadline: "",
            missedDays: 0,
            categoryBreakdown: [:],
            dailyEntryCounts: [:]
        )
        #expect(service.headlineType(for: summary) == .perfect)
    }

    @Test("headlineType returns default when no special condition met")
    func testHeadlineTypeDefault() throws {
        let service = WeeklySummaryService()
        let summary = WeeklySummary(
            weekStartDate: thisMonday(),
            totalEntries: 4,
            topFoodItem: "soup",
            topFoodCount: 1,
            topCategory: .dinner,
            bestDay: nil,
            currentStreak: 2,
            longestStreak: 2,
            uniqueFoodsCount: 3,
            vsLastWeek: 0,
            mostActiveHour: nil,
            headline: "",
            subheadline: "",
            missedDays: 4,
            categoryBreakdown: [:],
            dailyEntryCounts: [:]
        )
        #expect(service.headlineType(for: summary) == .default)
    }

    @Test("weekStartDate is Monday of current week")
    func testWeekStartDateIsMonday() throws {
        let service = WeeklySummaryService()
        let summary = service.generateSummary(from: [])
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: summary.weekStartDate)
        // weekday 2 = Monday in Gregorian calendar
        #expect(weekday == 2)
    }

    @Test("categoryBreakdown reflects only this week's entries")
    func testCategoryBreakdownThisWeek() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let _ = makeEntry(context: context, description: "lunch today", daysAgo: 0, category: .lunch)
        let _ = makeEntry(context: context, description: "lunch yesterday", daysAgo: 1, category: .lunch)
        let _ = makeEntry(context: context, description: "old dinner", daysAgo: 8, category: .dinner)
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        let service = WeeklySummaryService()
        let summary = service.generateSummary(from: entries)
        #expect(summary.categoryBreakdown[.lunch] != nil)
        #expect(summary.categoryBreakdown[.dinner] == nil)
    }
}
