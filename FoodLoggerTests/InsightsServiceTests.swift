//
//  InsightsServiceTests.swift
//  FoodLoggerTests
//
//  Comprehensive tests for InsightsService analytics methods.
//

import Testing
import Foundation
import SwiftData
@testable import FoodLogger

@MainActor
struct InsightsServiceTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema([FoodEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    /// Creates a FoodEntry whose `date` is `daysAgo` calendar days before today (start of day),
    /// and whose `createdAt` is set to that day with the given `hour`.
    private func makeEntry(
        daysAgo: Int,
        description: String,
        category: MealCategory? = nil,
        inputType: InputType = .text,
        hour: Int = 12
    ) -> FoodEntry {
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        let date = cal.date(byAdding: .day, value: -daysAgo, to: base)!
        var components = cal.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        components.second = 0
        let createdAt = cal.date(from: components) ?? date
        return FoodEntry(
            date: date,
            rawInput: description,
            inputType: inputType,
            processedDescription: description,
            createdAt: createdAt,
            category: category
        )
    }

    /// Creates a FoodEntry with a `createdAt` exactly `secondsAgo` seconds before now.
    /// `date` is set to startOfDay for that createdAt.
    private func makeEntryWithCreatedAt(secondsAgo: TimeInterval, description: String) -> FoodEntry {
        let cal = Calendar.current
        let createdAt = Date().addingTimeInterval(-secondsAgo)
        let date = cal.startOfDay(for: createdAt)
        return FoodEntry(
            date: date,
            rawInput: description,
            inputType: .text,
            processedDescription: description,
            createdAt: createdAt
        )
    }

    private let service = InsightsService()

    // MARK: - topItems tests

    @Test func testTopItemsEmptyEntriesReturnsEmpty() {
        let result = service.topItems(from: [], period: .week)
        #expect(result.isEmpty)
    }

    @Test func testTopItemsCountsFrequency() {
        let entries = [
            makeEntry(daysAgo: 0, description: "pizza"),
            makeEntry(daysAgo: 0, description: "pizza"),
            makeEntry(daysAgo: 0, description: "pizza"),
            makeEntry(daysAgo: 0, description: "salad"),
            makeEntry(daysAgo: 0, description: "salad"),
            makeEntry(daysAgo: 0, description: "soup"),
        ]
        let result = service.topItems(from: entries, period: .week)
        #expect(result.first?.item == "pizza")
        #expect(result.first?.count == 3)
    }

    @Test func testTopItemsRespectsPeriodFilter() {
        // Entry 10 days ago (createdAt 10 days ago) is outside the .week (7 day) window
        let oldEntry = makeEntry(daysAgo: 10, description: "oldpizza")
        let recentEntry = makeEntry(daysAgo: 0, description: "freshsalad")
        let result = service.topItems(from: [oldEntry, recentEntry], period: .week)
        let items = result.map { $0.item }
        #expect(!items.contains("oldpizza"))
        #expect(items.contains("freshsalad"))
    }

    @Test func testTopItemsStripsStopwords() {
        // "a" and "with" should be stripped; "pizza" and "cheese" should be kept
        let entry = makeEntry(daysAgo: 0, description: "a pizza with cheese")
        let result = service.topItems(from: [entry], period: .week)
        let items = result.map { $0.item }
        #expect(items.contains("pizza"))
        #expect(items.contains("cheese"))
        #expect(!items.contains("a"))
        #expect(!items.contains("with"))
    }

    @Test func testTopItemsRespectsLimit() {
        // 20 unique single-word descriptions
        let entries = (0..<20).map { i in
            makeEntry(daysAgo: 0, description: "uniquefood\(i)")
        }
        let result = service.topItems(from: entries, period: .week, limit: 5)
        #expect(result.count == 5)
    }

    // MARK: - dailyCounts tests

    @Test func testDailyCountsEmptyReturnsFilledZeros() {
        let result = service.dailyCounts(from: [], period: .week)
        // Should return 8 items: from 7 days ago through today (inclusive)
        #expect(result.count == 8)
        #expect(result.allSatisfy { $0.count == 0 })
    }

    @Test func testDailyCountsCountsCorrectly() {
        let today0 = makeEntry(daysAgo: 0, description: "breakfast")
        let today1 = makeEntry(daysAgo: 0, description: "dinner")
        let yesterday = makeEntry(daysAgo: 1, description: "lunch")
        let result = service.dailyCounts(from: [today0, today1, yesterday], period: .week)

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)!

        let todayCount = result.first(where: { $0.date == todayStart })?.count
        let yesterdayCount = result.first(where: { $0.date == yesterdayStart })?.count

        #expect(todayCount == 2)
        #expect(yesterdayCount == 1)
    }

    @Test func testDailyCountsPeriodWeekHas8Days() {
        // Period .week spans from 7 days ago through today = 8 days
        let result = service.dailyCounts(from: [], period: .week)
        #expect(result.count == 8)
    }

    @Test func testDailyCountsEntriesOutsidePeriodExcluded() {
        // filterByPeriod uses createdAt; entry with createdAt 10 days ago is outside .week
        let oldEntry = makeEntry(daysAgo: 10, description: "old food")
        let result = service.dailyCounts(from: [oldEntry], period: .week)
        #expect(result.allSatisfy { $0.count == 0 })
    }

    // MARK: - categoryDistribution tests

    @Test func testCategoryDistributionEmptyReturnsEmpty() {
        let result = service.categoryDistribution(from: [], period: .week)
        #expect(result.isEmpty)
    }

    @Test func testCategoryDistributionCorrectCounts() {
        let entries = [
            makeEntry(daysAgo: 0, description: "eggs", category: .breakfast),
            makeEntry(daysAgo: 0, description: "toast", category: .breakfast),
            makeEntry(daysAgo: 0, description: "pancakes", category: .breakfast),
            makeEntry(daysAgo: 0, description: "salad", category: .lunch),
            makeEntry(daysAgo: 0, description: "sandwich", category: .lunch),
            makeEntry(daysAgo: 0, description: "pasta", category: .dinner),
        ]
        let result = service.categoryDistribution(from: entries, period: .allTime)
        let breakfast = result.first(where: { $0.category == .breakfast })
        let lunch = result.first(where: { $0.category == .lunch })
        let dinner = result.first(where: { $0.category == .dinner })
        #expect(breakfast?.count == 3)
        #expect(lunch?.count == 2)
        #expect(dinner?.count == 1)
        // Sorted descending by count
        #expect(result.first?.category == .breakfast)
    }

    @Test func testCategoryDistributionPercentagesSumTo100() {
        let entries = [
            makeEntry(daysAgo: 0, description: "eggs", category: .breakfast),
            makeEntry(daysAgo: 0, description: "salad", category: .lunch),
            makeEntry(daysAgo: 0, description: "pasta", category: .dinner),
            makeEntry(daysAgo: 0, description: "cake", category: .dessert),
        ]
        let result = service.categoryDistribution(from: entries, period: .allTime)
        let sum = result.map { $0.percentage }.reduce(0, +)
        #expect(abs(sum - 100.0) < 0.01)
    }

    @Test func testCategoryDistributionEntriesWithNilCategoryExcluded() {
        let entries = [
            makeEntry(daysAgo: 0, description: "mystery food", category: nil),
            makeEntry(daysAgo: 0, description: "eggs", category: .breakfast),
        ]
        let result = service.categoryDistribution(from: entries, period: .allTime)
        // Only breakfast should be present; nil-category entry should not appear
        #expect(result.count == 1)
        #expect(result.first?.category == .breakfast)
        // The percentage is computed against total entries (including nil-category),
        // so breakfast with 1 out of 2 total = 50%
        #expect(abs((result.first?.percentage ?? 0) - 50.0) < 0.01)
    }

    // MARK: - inputTypeBreakdown tests

    @Test func testInputTypeBreakdownEmptyReturnsEmpty() {
        let result = service.inputTypeBreakdown(from: [], period: .week)
        #expect(result.isEmpty)
    }

    @Test func testInputTypeBreakdownAllThreeTypes() {
        let entries = [
            makeEntry(daysAgo: 0, description: "text food", inputType: .text),
            makeEntry(daysAgo: 0, description: "voice food", inputType: .voice),
            makeEntry(daysAgo: 0, description: "image food", inputType: .image),
        ]
        let result = service.inputTypeBreakdown(from: entries, period: .allTime)
        #expect(result.count == 3)
        let inputTypes = result.map { $0.inputType }
        #expect(inputTypes.contains(.text))
        #expect(inputTypes.contains(.voice))
        #expect(inputTypes.contains(.image))
        // Each should be ~33.33%
        for item in result {
            #expect(abs(item.percentage - 33.33) < 0.5)
        }
    }

    @Test func testInputTypeBreakdownPercentagesSumTo100() {
        let entries = [
            makeEntry(daysAgo: 0, description: "food1", inputType: .text),
            makeEntry(daysAgo: 0, description: "food2", inputType: .text),
            makeEntry(daysAgo: 0, description: "food3", inputType: .voice),
            makeEntry(daysAgo: 0, description: "food4", inputType: .image),
        ]
        let result = service.inputTypeBreakdown(from: entries, period: .allTime)
        let sum = result.map { $0.percentage }.reduce(0, +)
        #expect(abs(sum - 100.0) < 0.01)
    }

    // MARK: - mealTiming tests

    @Test func testMealTimingEmptyReturnsAllHoursWithZeroCount() {
        // mealTiming always returns 24 entries (one per hour, 0..<24) even for empty input
        let result = service.mealTiming(from: [], period: .week)
        #expect(result.count == 24)
        #expect(result.allSatisfy { $0.count == 0 })
    }

    @Test func testMealTimingGroupsByHour() {
        let morningEntry = makeEntry(daysAgo: 0, description: "breakfast", hour: 8)
        let noonEntry = makeEntry(daysAgo: 0, description: "lunch", hour: 12)
        let result = service.mealTiming(from: [morningEntry, noonEntry], period: .allTime)
        let hour8 = result.first(where: { $0.hour == 8 })
        let hour12 = result.first(where: { $0.hour == 12 })
        #expect(hour8?.count == 1)
        #expect(hour12?.count == 1)
    }

    @Test func testMealTimingCountsCorrectly() {
        let entries = [
            makeEntry(daysAgo: 0, description: "breakfast1", hour: 8),
            makeEntry(daysAgo: 0, description: "breakfast2", hour: 8),
            makeEntry(daysAgo: 0, description: "breakfast3", hour: 8),
        ]
        let result = service.mealTiming(from: entries, period: .allTime)
        let hour8 = result.first(where: { $0.hour == 8 })
        #expect(hour8?.count == 3)
    }

    // MARK: - weekOverWeekTrend tests
    //
    // weekOverWeekTrend computes:
    //   thisWeek  = entries where createdAt is in [now-7days, now]
    //   lastWeek  = entries where createdAt is in [now-14days, now-7days)
    //
    // We use second-precision offsets so entries land unambiguously inside
    // each window regardless of the time of day tests run.
    //
    // "This week" window: createdAt within the last 7*24*3600 seconds.
    // "Last week" window: createdAt between 14*24*3600 and 7*24*3600 seconds ago.
    // Safe midpoints: 3 days ago (259200 s) and 10 days ago (864000 s).

    private let oneDay: TimeInterval    = 86_400
    private let threeDays: TimeInterval = 3 * 86_400
    private let tenDays: TimeInterval   = 10 * 86_400

    @Test func testWeekOverWeekBothZero() {
        let result = service.weekOverWeekTrend(from: [])
        #expect(result.thisWeek == 0)
        #expect(result.lastWeek == 0)
        #expect(result.changePercent == 0)
    }

    @Test func testWeekOverWeekThisWeekOnly() {
        // 3 entries clearly within this week, 0 in last week
        let entries = [
            makeEntryWithCreatedAt(secondsAgo: oneDay,      description: "food1"),
            makeEntryWithCreatedAt(secondsAgo: oneDay * 2,  description: "food2"),
            makeEntryWithCreatedAt(secondsAgo: threeDays,   description: "food3"),
        ]
        let result = service.weekOverWeekTrend(from: entries)
        #expect(result.thisWeek == 3)
        #expect(result.lastWeek == 0)
        // lastWeek == 0 and thisWeek > 0 → changePercent == 100
        #expect(result.changePercent == 100.0)
    }

    @Test func testWeekOverWeekPositiveTrend() {
        // 5 entries this week, 2 last week
        var entries: [FoodEntry] = []
        // This week: 1–6 days ago at midday
        for i in 1...5 {
            entries.append(makeEntryWithCreatedAt(secondsAgo: TimeInterval(i) * oneDay, description: "thisweek\(i)"))
        }
        // Last week: 8 and 9 days ago (midpoint of the 7–14 day window)
        entries.append(makeEntryWithCreatedAt(secondsAgo: oneDay * 8, description: "lastweek1"))
        entries.append(makeEntryWithCreatedAt(secondsAgo: oneDay * 9, description: "lastweek2"))
        let result = service.weekOverWeekTrend(from: entries)
        #expect(result.thisWeek == 5)
        #expect(result.lastWeek == 2)
        #expect(result.changePercent > 0)
    }

    // MARK: - monthlyHeatmap tests

    @Test func testMonthlyHeatmapHasAllDaysInMonth() {
        let cal = Calendar.current
        // Use February 2026 (28 days — 2026 is not a leap year)
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 2
        comps.day = 1
        let feb2026 = cal.date(from: comps)!
        let result = service.monthlyHeatmap(from: [], month: feb2026)
        #expect(result.count == 28)
    }

    @Test func testMonthlyHeatmapCountsEntriesCorrectly() {
        let cal = Calendar.current
        // Build two entries for January 15, 2026
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 1
        comps.day = 15
        let jan15 = cal.date(from: comps)!
        let jan15Start = cal.startOfDay(for: jan15)

        let entry1 = FoodEntry(
            date: jan15Start,
            rawInput: "oatmeal",
            inputType: .text,
            processedDescription: "oatmeal"
        )
        let entry2 = FoodEntry(
            date: jan15Start,
            rawInput: "coffee",
            inputType: .text,
            processedDescription: "coffee"
        )

        var monthComps = DateComponents()
        monthComps.year = 2026
        monthComps.month = 1
        monthComps.day = 1
        let jan2026 = cal.date(from: monthComps)!

        let result = service.monthlyHeatmap(from: [entry1, entry2], month: jan2026)
        let day15 = result.first(where: { $0.date == jan15Start })
        #expect(day15?.count == 2)
    }

    @Test func testMonthlyHeatmapDaysWithNoEntriesHaveZeroCount() {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 3
        comps.day = 1
        let mar2026 = cal.date(from: comps)!
        let result = service.monthlyHeatmap(from: [], month: mar2026)
        #expect(result.allSatisfy { $0.count == 0 })
    }

    // MARK: - coOccurrence tests

    @Test func testCoOccurrenceEmptyReturnsEmpty() {
        let result = service.coOccurrence(from: [], period: .week)
        #expect(result.isEmpty)
    }

    @Test func testCoOccurrenceFindsCoOccurringItems() {
        // Two entries on the same day with "pizza" and "salad"
        let entry1 = makeEntry(daysAgo: 0, description: "pizza")
        let entry2 = makeEntry(daysAgo: 0, description: "salad")
        let result = service.coOccurrence(from: [entry1, entry2], period: .allTime)
        // Should find a pair containing both "pizza" and "salad"
        let pairFound = result.contains(where: {
            ($0.item1 == "pizza" && $0.item2 == "salad") ||
            ($0.item1 == "salad" && $0.item2 == "pizza")
        })
        #expect(pairFound)
    }

    // MARK: - Additional edge case tests

    @Test func testTopItemsSingleWordStrippedWhenLengthOne() {
        // Single-character words should be stripped by the tokeniser (count > 1 filter)
        let entry = makeEntry(daysAgo: 0, description: "i pizza")
        let result = service.topItems(from: [entry], period: .week)
        let items = result.map { $0.item }
        #expect(!items.contains("i"))
        #expect(items.contains("pizza"))
    }

    @Test func testCategoryDistributionSortedByCountDescending() {
        let entries = [
            makeEntry(daysAgo: 0, description: "dinner1", category: .dinner),
            makeEntry(daysAgo: 0, description: "dinner2", category: .dinner),
            makeEntry(daysAgo: 0, description: "dinner3", category: .dinner),
            makeEntry(daysAgo: 0, description: "lunch1", category: .lunch),
        ]
        let result = service.categoryDistribution(from: entries, period: .allTime)
        #expect(result.first?.category == .dinner)
        #expect(result.last?.category == .lunch)
    }

    @Test func testInputTypeBreakdownSingleType() {
        let entries = [
            makeEntry(daysAgo: 0, description: "food1", inputType: .text),
            makeEntry(daysAgo: 0, description: "food2", inputType: .text),
        ]
        let result = service.inputTypeBreakdown(from: entries, period: .allTime)
        #expect(result.count == 1)
        #expect(result.first?.inputType == .text)
        #expect(abs((result.first?.percentage ?? 0) - 100.0) < 0.01)
    }

    @Test func testDailyCountsAllTimeReturnsOnlyDaysWithEntries() {
        // allTime period returns only days that have entries (no zero-fill)
        let entry = makeEntry(daysAgo: 5, description: "food")
        let result = service.dailyCounts(from: [entry], period: .allTime)
        // For allTime, no zero-fill — only 1 day returned
        #expect(result.count == 1)
        #expect(result.first?.count == 1)
    }

    @Test func testWeekOverWeekNegativeTrend() {
        // 2 this week, 5 last week → negative change percent
        var entries: [FoodEntry] = []
        entries.append(makeEntryWithCreatedAt(secondsAgo: oneDay,     description: "food1"))
        entries.append(makeEntryWithCreatedAt(secondsAgo: oneDay * 2, description: "food2"))
        // Last week entries (8–12 days ago — clearly in the 7–14 day window)
        for i in 8..<13 {
            entries.append(makeEntryWithCreatedAt(secondsAgo: TimeInterval(i) * oneDay, description: "last\(i)"))
        }
        let result = service.weekOverWeekTrend(from: entries)
        #expect(result.thisWeek == 2)
        #expect(result.lastWeek == 5)
        #expect(result.changePercent < 0)
    }

    @Test func testCoOccurrenceNoCoOccurrenceOnDifferentDays() {
        // Two entries on different days — no pair expected
        let entry1 = makeEntry(daysAgo: 0, description: "pizza")
        let entry2 = makeEntry(daysAgo: 1, description: "salad")
        let result = service.coOccurrence(from: [entry1, entry2], period: .allTime)
        let pairFound = result.contains(where: {
            ($0.item1 == "pizza" && $0.item2 == "salad") ||
            ($0.item1 == "salad" && $0.item2 == "pizza")
        })
        #expect(!pairFound)
    }

    @Test func testMealTimingAlwaysReturns24Hours() {
        let entries = [
            makeEntry(daysAgo: 0, description: "food", hour: 7),
            makeEntry(daysAgo: 0, description: "food", hour: 19),
        ]
        let result = service.mealTiming(from: entries, period: .allTime)
        #expect(result.count == 24)
        let hours = result.map { $0.hour }
        #expect(hours.contains(0))
        #expect(hours.contains(23))
    }

    @Test func testTopItemsAllTimeIncludesOldEntries() {
        // allTime period should include entries regardless of age
        let oldEntry = makeEntry(daysAgo: 400, description: "ancientfood")
        let result = service.topItems(from: [oldEntry], period: .allTime)
        let items = result.map { $0.item }
        #expect(items.contains("ancientfood"))
    }

    @Test func testCategoryDistributionPeriodFiltering() {
        // Entry outside period window should not be counted
        let oldEntry = makeEntry(daysAgo: 10, description: "breakfast", category: .breakfast)
        let recentEntry = makeEntry(daysAgo: 0, description: "lunch", category: .lunch)
        let result = service.categoryDistribution(from: [oldEntry, recentEntry], period: .week)
        // oldEntry is outside .week window → only lunch should appear
        let cats = result.map { $0.category }
        #expect(!cats.contains(.breakfast))
        #expect(cats.contains(.lunch))
    }

    @Test func testMonthlyHeatmapExcludesEntriesFromOtherMonths() {
        let cal = Calendar.current
        // Entry in January should NOT appear in February heatmap
        var janComps = DateComponents()
        janComps.year = 2026
        janComps.month = 1
        janComps.day = 31
        let jan31 = cal.startOfDay(for: cal.date(from: janComps)!)

        let entry = FoodEntry(
            date: jan31,
            rawInput: "food",
            inputType: .text,
            processedDescription: "food"
        )

        var febComps = DateComponents()
        febComps.year = 2026
        febComps.month = 2
        febComps.day = 1
        let feb2026 = cal.date(from: febComps)!

        let result = service.monthlyHeatmap(from: [entry], month: feb2026)
        #expect(result.allSatisfy { $0.count == 0 })
    }
}
