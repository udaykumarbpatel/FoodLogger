//
//  SampleDataService.swift
//  FoodLogger
//
//  Seeds 120 days of realistic food diary sample data when the store is empty.
//

import Foundation
import SwiftData

@MainActor final class SampleDataService {

    // MARK: - Food catalogue

    private struct FoodItem {
        let name: String
        let category: MealCategory
    }

    private static let catalogue: [FoodItem] = [
        // Beverages
        FoodItem(name: "Oat milk latte",          category: .beverage),
        FoodItem(name: "Espresso",                 category: .beverage),
        FoodItem(name: "Matcha latte",             category: .beverage),
        FoodItem(name: "Cappuccino",               category: .beverage),
        FoodItem(name: "Mango lassi",              category: .beverage),
        FoodItem(name: "Protein shake",            category: .beverage),
        FoodItem(name: "Cold brew coffee",         category: .beverage),
        FoodItem(name: "Almond milk flat white",   category: .beverage),
        FoodItem(name: "Green smoothie",           category: .beverage),
        // Breakfast
        FoodItem(name: "Avocado toast",            category: .breakfast),
        FoodItem(name: "Greek yogurt",             category: .breakfast),
        FoodItem(name: "Overnight oats",           category: .breakfast),
        FoodItem(name: "Acai bowl",                category: .breakfast),
        FoodItem(name: "Idli sambar",              category: .breakfast),
        FoodItem(name: "Masala dosa",              category: .breakfast),
        FoodItem(name: "Quinoa bowl",              category: .breakfast),
        FoodItem(name: "Chia pudding",             category: .breakfast),
        // Lunch
        FoodItem(name: "Caesar salad",             category: .lunch),
        FoodItem(name: "Turkey sandwich",          category: .lunch),
        FoodItem(name: "Pad thai",                 category: .lunch),
        FoodItem(name: "Sushi",                    category: .lunch),
        FoodItem(name: "Veggie burger",            category: .lunch),
        FoodItem(name: "Pho",                      category: .lunch),
        FoodItem(name: "Ramen",                    category: .lunch),
        // Dinner
        FoodItem(name: "Biryani",                  category: .dinner),
        FoodItem(name: "Grilled salmon",           category: .dinner),
        FoodItem(name: "Chicken tikka",            category: .dinner),
        FoodItem(name: "Butter chicken",           category: .dinner),
        FoodItem(name: "Dal makhani",              category: .dinner),
        FoodItem(name: "Palak paneer",             category: .dinner),
        FoodItem(name: "Steak",                    category: .dinner),
        FoodItem(name: "Chana masala",             category: .dinner),
        // Snack
        FoodItem(name: "Samosa",                   category: .snack),
        // Dessert
        FoodItem(name: "Kheer",                    category: .dessert),
        FoodItem(name: "Fruit salad",              category: .dessert),
    ]

    // MARK: - Meal slot definitions

    private struct MealSlot {
        let hourRange: ClosedRange<Int>
        let minuteRange: ClosedRange<Int>
        let preferredCategories: [MealCategory]
    }

    private static let mealSlots: [MealSlot] = [
        MealSlot(hourRange: 7...9,   minuteRange: 0...45, preferredCategories: [.breakfast, .beverage]),
        MealSlot(hourRange: 12...14, minuteRange: 0...45, preferredCategories: [.lunch,     .beverage]),
        MealSlot(hourRange: 15...16, minuteRange: 0...30, preferredCategories: [.snack,     .beverage, .dessert]),
        MealSlot(hourRange: 19...21, minuteRange: 0...45, preferredCategories: [.dinner,    .beverage, .dessert]),
    ]

    // MARK: - Seed

    /// Seeds only when the store is completely empty. No-op if any FoodEntry exists.
    func seedIfNeeded(context: ModelContext) {
        var descriptor = FetchDescriptor<FoodEntry>()
        descriptor.fetchLimit = 1
        let existing = (try? context.fetch(descriptor)) ?? []
        guard existing.isEmpty else { return }
        seed(context: context)
    }

    /// Unconditionally inserts 120 days of sample data. Use this after clearing sample
    /// entries so re-seeding works even when real entries are present.
    func seed(context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Deterministic pseudo-random sequence using a simple LCG
        var rng = SeededRNG(seed: 42)

        for dayOffset in (0..<120).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }

            // About 15% of days are empty (0 entries)
            let emptyRoll = rng.next() % 100
            if emptyRoll < 15 { continue }

            // 1, 2, or 3 entries — weighted toward 2
            let entryCountRoll = rng.next() % 10
            let entryCount: Int
            switch entryCountRoll {
            case 0...2:  entryCount = 1
            case 3...7:  entryCount = 2
            default:     entryCount = 3
            }

            // Pick slots for the day (no duplicates)
            var slotIndices = Array(0..<Self.mealSlots.count)
            shuffleArray(&slotIndices, rng: &rng)
            let chosenSlots = Array(slotIndices.prefix(entryCount))

            for slotIndex in chosenSlots.sorted() {
                let slot = Self.mealSlots[slotIndex]

                // Pick a food item that fits the slot's preferred categories
                let candidates = Self.catalogue.filter { slot.preferredCategories.contains($0.category) }
                let pool = candidates.isEmpty ? Self.catalogue : candidates
                let foodItem = pool[Int(rng.next()) % pool.count]

                // Build createdAt with a realistic time
                let hour   = slot.hourRange.lowerBound + Int(rng.next()) % (slot.hourRange.upperBound - slot.hourRange.lowerBound + 1)
                let minute = slot.minuteRange.lowerBound + Int(rng.next()) % (slot.minuteRange.upperBound - slot.minuteRange.lowerBound + 1)

                var components = calendar.dateComponents([.year, .month, .day], from: day)
                components.hour   = hour
                components.minute = minute
                components.second = Int(rng.next()) % 60
                let createdAt = calendar.date(from: components) ?? day

                // Determine inputType (text ~60%, voice ~25%, image ~15%)
                let typeRoll = rng.next() % 100
                let inputType: InputType
                switch typeRoll {
                case 0..<60:  inputType = .text
                case 60..<85: inputType = .voice
                default:      inputType = .image
                }

                let (rawInput, processedDescription, mediaURL) = buildContent(
                    for: foodItem.name,
                    inputType: inputType,
                    rng: &rng
                )

                let entry = FoodEntry(
                    id: UUID(),
                    date: day,
                    rawInput: rawInput,
                    inputType: inputType,
                    processedDescription: processedDescription,
                    mediaURL: mediaURL,
                    createdAt: createdAt,
                    category: foodItem.category,
                    updatedAt: nil
                )
                context.insert(entry)
            }
        }

        try? context.save()
    }

    // MARK: - Content builder

    private func buildContent(
        for foodName: String,
        inputType: InputType,
        rng: inout SeededRNG
    ) -> (rawInput: String, processedDescription: String, mediaURL: URL?) {
        switch inputType {
        case .text:
            let raw = "[SAMPLE] " + foodName
            return (raw, foodName, nil)

        case .voice:
            let processed = "I had " + foodName
            let raw = "[SAMPLE] " + processed
            return (raw, processed, nil)

        case .image:
            let filename = UUID().uuidString + ".jpg"
            let raw = "[SAMPLE] " + filename
            let processed = foodName + " dish"
            // Per CLAUDE.md mediaURL rule: store only the bare filename
            // For sample data we have no real image, so mediaURL = nil
            return (raw, processed, nil)
        }
    }

    // MARK: - Array shuffle using seeded RNG

    private func shuffleArray<T>(_ array: inout [T], rng: inout SeededRNG) {
        for i in stride(from: array.count - 1, through: 1, by: -1) {
            let j = Int(rng.next()) % (i + 1)
            array.swapAt(i, j)
        }
    }
}

// MARK: - Seeded pseudo-random number generator (LCG)

/// A simple Linear Congruential Generator for deterministic sample data.
/// Not cryptographically secure — used only for predictable seed data.
private struct SeededRNG {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // Parameters from Knuth's MMIX
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state >> 33
    }
}
