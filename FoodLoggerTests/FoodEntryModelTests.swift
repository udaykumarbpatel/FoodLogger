import Testing
import Foundation
import SwiftData
@testable import FoodLogger

// Tests for the FoodEntry model and SwiftData persistence
@MainActor
struct FoodEntryModelTests {

    // Creates an in-memory SwiftData container for test isolation
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([FoodEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    // MARK: - Model initialisation

    @Test("FoodEntry initialises with correct values")
    func entryInitialisesCorrectly() throws {
        let now = Date()
        let entry = FoodEntry(
            date: now,
            rawInput: "had pizza",
            inputType: .text,
            processedDescription: "pizza"
        )
        #expect(entry.rawInput == "had pizza")
        #expect(entry.inputType == .text)
        #expect(entry.processedDescription == "pizza")
        #expect(entry.mediaURL == nil)
    }

    @Test("FoodEntry UUID is unique per instance")
    func entryUUIDsAreUnique() {
        let a = FoodEntry(date: .now, rawInput: "a", inputType: .text, processedDescription: "a")
        let b = FoodEntry(date: .now, rawInput: "b", inputType: .text, processedDescription: "b")
        #expect(a.id != b.id)
    }

    // MARK: - InputType enum

    @Test("InputType raw values are stable strings")
    func inputTypeRawValues() {
        #expect(InputType.text.rawValue == "text")
        #expect(InputType.image.rawValue == "image")
        #expect(InputType.voice.rawValue == "voice")
    }

    @Test("InputType round-trips through rawValue")
    func inputTypeRoundTrips() {
        for type_ in InputType.allCases {
            let decoded = InputType(rawValue: type_.rawValue)
            #expect(decoded == type_)
        }
    }

    // MARK: - SwiftData persistence

    @Test("Inserted entry is fetchable")
    func insertAndFetch() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let entry = FoodEntry(
            date: Calendar.current.startOfDay(for: .now),
            rawInput: "salmon and rice",
            inputType: .voice,
            processedDescription: "salmon, rice"
        )
        context.insert(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<FoodEntry>())
        #expect(fetched.count == 1)
        #expect(fetched[0].processedDescription == "salmon, rice")
    }

    @Test("Deleted entry is no longer fetchable")
    func insertThenDelete() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let entry = FoodEntry(
            date: .now,
            rawInput: "test",
            inputType: .text,
            processedDescription: "test"
        )
        context.insert(entry)
        try context.save()

        context.delete(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<FoodEntry>())
        #expect(fetched.isEmpty)
    }

    @Test("Date predicate filters entries by day correctly")
    func datePredicate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let calendar = Calendar.current

        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let todayEntry = FoodEntry(date: today, rawInput: "today", inputType: .text, processedDescription: "today")
        let yesterdayEntry = FoodEntry(date: yesterday, rawInput: "yesterday", inputType: .text, processedDescription: "yesterday")
        context.insert(todayEntry)
        context.insert(yesterdayEntry)
        try context.save()

        let end = calendar.date(byAdding: .day, value: 1, to: today)!
        let descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { entry in
                entry.date >= today && entry.date < end
            }
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results[0].rawInput == "today")
    }

    @Test("Multiple entries on same day all appear in query")
    func multipleEntriesSameDay() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let today = Calendar.current.startOfDay(for: .now)

        for i in 1...3 {
            context.insert(FoodEntry(
                date: today,
                rawInput: "meal \(i)",
                inputType: .text,
                processedDescription: "meal \(i)"
            ))
        }
        try context.save()

        let end = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        let descriptor = FetchDescriptor<FoodEntry>(
            predicate: #Predicate { e in e.date >= today && e.date < end },
            sortBy: [SortDescriptor(\FoodEntry.createdAt)]
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 3)
    }
}
