import Foundation

struct StreakService {

    struct StreakInfo {
        let count: Int
        let hasEntryToday: Bool
    }

    func compute(from entries: [FoodEntry]) -> StreakInfo {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let daysWithEntries = Set(entries.map { calendar.startOfDay(for: $0.date) })
        let hasEntryToday = daysWithEntries.contains(today)

        // Count backward from today (if logged) or yesterday (if not)
        var cursor = hasEntryToday ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        var count = 0
        while daysWithEntries.contains(cursor) {
            count += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        return StreakInfo(count: count, hasEntryToday: hasEntryToday)
    }
}
