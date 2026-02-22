import Testing
@testable import FoodLogger

@MainActor
struct MealCategoryTests {

    let service = CategoryDetectionService()

    // MARK: - Content-first: beverage keyword beats time

    @Test func beverageKeywordBeatsBreakfastHour() {
        let result = service.detect(hour: 8, description: "morning smoothie", visionLabels: [])
        #expect(result == .beverage)
    }

    @Test func beverageKeywordBeatsDinnerHour() {
        let result = service.detect(hour: 19, description: "glass of wine", visionLabels: [])
        #expect(result == .beverage)
    }

    @Test func beverageViaVisionLabel() {
        let result = service.detect(hour: 12, description: "Photo", visionLabels: ["coffee"])
        #expect(result == .beverage)
    }

    // MARK: - Content-first: dessert keyword beats time

    @Test func dessertKeywordBeatsLunchHour() {
        let result = service.detect(hour: 12, description: "chocolate cake", visionLabels: [])
        #expect(result == .dessert)
    }

    @Test func dessertViaVisionLabel() {
        let result = service.detect(hour: 18, description: "Photo", visionLabels: ["donut"])
        #expect(result == .dessert)
    }

    // MARK: - Time buckets

    @Test func breakfastHour() {
        let result = service.detect(hour: 7, description: "oatmeal", visionLabels: [])
        #expect(result == .breakfast)
    }

    @Test func lunchHour() {
        let result = service.detect(hour: 13, description: "sandwich", visionLabels: [])
        #expect(result == .lunch)
    }

    @Test func snackHour() {
        let result = service.detect(hour: 15, description: "apple", visionLabels: [])
        #expect(result == .snack)
    }

    @Test func dinnerHour() {
        let result = service.detect(hour: 19, description: "pasta", visionLabels: [])
        #expect(result == .dinner)
    }

    @Test func lateNightFallback() {
        let result = service.detect(hour: 2, description: "crackers", visionLabels: [])
        #expect(result == .snack)
    }

    // MARK: - Case-insensitive matching

    @Test func caseInsensitiveBeverage() {
        let result = service.detect(hour: 10, description: "COFFEE", visionLabels: [])
        #expect(result == .beverage)
    }

    @Test func caseInsensitiveDessert() {
        let result = service.detect(hour: 14, description: "Chocolate Brownie", visionLabels: [])
        #expect(result == .dessert)
    }

    // MARK: - Beverage takes priority over dessert

    @Test func beveragePriorityOverDessert() {
        let result = service.detect(hour: 15, description: "chocolate milk", visionLabels: [])
        #expect(result == .beverage)
    }
}
