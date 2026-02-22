//
//  SampleDataServiceTests.swift
//  FoodLoggerTests
//
//  Tests for SampleDataService seeding behavior.
//

import Testing
import Foundation
import SwiftData
@testable import FoodLogger

@MainActor
struct SampleDataServiceTests {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema([FoodEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func fetchAllEntries(from context: ModelContext) throws -> [FoodEntry] {
        let descriptor = FetchDescriptor<FoodEntry>()
        return try context.fetch(descriptor)
    }

    private let service = SampleDataService()

    // MARK: - Tests

    @Test func testSeedsWhenEmpty() throws {
        let context = try makeContext()
        service.seedIfNeeded(context: context)
        let entries = try fetchAllEntries(from: context)
        #expect(entries.count > 0)
    }

    @Test func testSkipsWhenDataExists() throws {
        let context = try makeContext()
        service.seedIfNeeded(context: context)
        let countAfterFirstSeed = try fetchAllEntries(from: context).count
        service.seedIfNeeded(context: context)
        let countAfterSecondSeed = try fetchAllEntries(from: context).count
        #expect(countAfterFirstSeed == countAfterSecondSeed)
    }

    @Test func testAllSixCategoriesPresent() throws {
        let context = try makeContext()
        service.seedIfNeeded(context: context)
        let entries = try fetchAllEntries(from: context)
        let presentCategories = Set(entries.compactMap { $0.category })
        for category in MealCategory.allCases {
            #expect(presentCategories.contains(category), "Expected category \(category.rawValue) to be present in seeded data")
        }
    }

    @Test func testAllThreeInputTypesPresent() throws {
        let context = try makeContext()
        service.seedIfNeeded(context: context)
        let entries = try fetchAllEntries(from: context)
        let presentTypes = Set(entries.map { $0.inputType })
        for inputType in InputType.allCases {
            #expect(presentTypes.contains(inputType), "Expected inputType \(inputType.rawValue) to be present in seeded data")
        }
    }

    @Test func testNoFutureDates() throws {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let context = try makeContext()
        service.seedIfNeeded(context: context)
        let entries = try fetchAllEntries(from: context)
        for entry in entries {
            #expect(entry.date <= todayStart, "Found future-dated entry: \(entry.date)")
        }
    }

    @Test func testAllEntriesHaveSamplePrefix() throws {
        let context = try makeContext()
        service.seedIfNeeded(context: context)
        let entries = try fetchAllEntries(from: context)
        for entry in entries {
            #expect(entry.rawInput.hasPrefix("[SAMPLE]"), "rawInput '\(entry.rawInput)' does not start with [SAMPLE]")
        }
    }

    @Test func testSeedCount() throws {
        // 120 days, ~15% empty days, 1–3 entries per non-empty day → at least 70 entries
        let context = try makeContext()
        service.seedIfNeeded(context: context)
        let entries = try fetchAllEntries(from: context)
        #expect(entries.count > 70)
    }

    @Test func testSeedForceSeedsRegardlessOfExistingEntries() throws {
        // seed() should add data even when entries already exist
        let context = try makeContext()
        service.seedIfNeeded(context: context)
        let countAfterFirst = try fetchAllEntries(from: context).count
        // seed() (unconditional) should add another full batch on top
        service.seed(context: context)
        let countAfterForce = try fetchAllEntries(from: context).count
        #expect(countAfterForce > countAfterFirst)
    }

    @Test func testDatesAreStartOfDay() throws {
        let cal = Calendar.current
        let context = try makeContext()
        service.seedIfNeeded(context: context)
        let entries = try fetchAllEntries(from: context)
        for entry in entries {
            let expectedStartOfDay = cal.startOfDay(for: entry.date)
            #expect(entry.date == expectedStartOfDay, "Entry date \(entry.date) is not start of day")
        }
    }

    @Test func testSeedIsDeterministic() throws {
        // Seeding twice in separate contexts should produce the same count (deterministic RNG)
        let context1 = try makeContext()
        service.seedIfNeeded(context: context1)
        let count1 = try fetchAllEntries(from: context1).count

        let context2 = try makeContext()
        service.seedIfNeeded(context: context2)
        let count2 = try fetchAllEntries(from: context2).count

        #expect(count1 == count2)
    }
}
