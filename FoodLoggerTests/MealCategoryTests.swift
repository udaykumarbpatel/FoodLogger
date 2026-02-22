import Testing
@testable import FoodLogger

@MainActor
struct MealCategoryTests {

    let service = CategoryDetectionService()

    // MARK: - Beverage keyword beats time

    @Test func beverageKeywordBeatsBreakfastHour() {
        #expect(service.detect(hour: 8,  description: "morning smoothie", visionLabels: []) == .beverage)
    }

    @Test func beverageKeywordBeatsDinnerHour() {
        #expect(service.detect(hour: 19, description: "glass of wine",    visionLabels: []) == .beverage)
    }

    @Test func beverageViaVisionLabel() {
        #expect(service.detect(hour: 12, description: "Photo", visionLabels: ["coffee"]) == .beverage)
    }

    @Test func latteAtDinnerTime() {
        #expect(service.detect(hour: 19, description: "latte",            visionLabels: []) == .beverage)
    }

    @Test func cappuccinoAtLunchHour() {
        #expect(service.detect(hour: 13, description: "cappuccino",       visionLabels: []) == .beverage)
    }

    @Test func kombuchaAtSnackHour() {
        #expect(service.detect(hour: 15, description: "kombucha",         visionLabels: []) == .beverage)
    }

    @Test func matchaAtBreakfastHour() {
        #expect(service.detect(hour: 7,  description: "matcha latte",     visionLabels: []) == .beverage)
    }

    // MARK: - Dessert keyword beats time

    @Test func dessertKeywordBeatsLunchHour() {
        #expect(service.detect(hour: 12, description: "chocolate cake",   visionLabels: []) == .dessert)
    }

    @Test func dessertViaVisionLabel() {
        #expect(service.detect(hour: 18, description: "Photo", visionLabels: ["donut"]) == .dessert)
    }

    @Test func cupcakeAtBreakfastHour() {
        #expect(service.detect(hour: 8,  description: "cupcake",          visionLabels: []) == .dessert)
    }

    @Test func gelatoAtDinnerHour() {
        #expect(service.detect(hour: 19, description: "gelato",           visionLabels: []) == .dessert)
    }

    @Test func cheesecakeAtLunchHour() {
        #expect(service.detect(hour: 12, description: "cheesecake slice", visionLabels: []) == .dessert)
    }

    // MARK: - Breakfast keyword beats time bucket

    @Test func oatmealKeywordAtDinnerHour() {
        #expect(service.detect(hour: 19, description: "oatmeal bowl",     visionLabels: []) == .breakfast)
    }

    @Test func pancakesAtLunchHour() {
        #expect(service.detect(hour: 13, description: "pancakes",         visionLabels: []) == .breakfast)
    }

    @Test func bagelAtSnackHour() {
        #expect(service.detect(hour: 15, description: "bagel with cream cheese", visionLabels: []) == .breakfast)
    }

    // MARK: - Lunch keyword beats time bucket

    @Test func sandwichAtBreakfastHour() {
        #expect(service.detect(hour: 8,  description: "club sandwich",    visionLabels: []) == .lunch)
    }

    @Test func saladAtDinnerHour() {
        #expect(service.detect(hour: 18, description: "caesar salad",     visionLabels: []) == .lunch)
    }

    @Test func burritoAtSnackHour() {
        #expect(service.detect(hour: 16, description: "burrito",          visionLabels: []) == .lunch)
    }

    // MARK: - Snack keyword beats time bucket

    @Test func chipsAtBreakfastHour() {
        #expect(service.detect(hour: 8,  description: "chips",            visionLabels: []) == .snack)
    }

    @Test func popcornAtDinnerHour() {
        #expect(service.detect(hour: 19, description: "popcorn",          visionLabels: []) == .snack)
    }

    @Test func nutsAtLunchHour() {
        #expect(service.detect(hour: 12, description: "mixed nuts",       visionLabels: []) == .snack)
    }

    // MARK: - Dinner keyword beats time bucket

    @Test func steakAtBreakfastHour() {
        #expect(service.detect(hour: 8,  description: "steak",            visionLabels: []) == .dinner)
    }

    @Test func pastaAtLunchHour() {
        #expect(service.detect(hour: 13, description: "pasta carbonara",  visionLabels: []) == .dinner)
    }

    @Test func curryAtSnackHour() {
        #expect(service.detect(hour: 15, description: "chicken curry",    visionLabels: []) == .dinner)
    }

    // MARK: - Time-bucket fallback (no keywords match)

    @Test func breakfastTimeBucket() {
        #expect(service.detect(hour: 7,  description: "something yummy",  visionLabels: []) == .breakfast)
    }

    @Test func lunchTimeBucket() {
        #expect(service.detect(hour: 13, description: "had a meal",       visionLabels: []) == .lunch)
    }

    @Test func snackTimeBucket() {
        #expect(service.detect(hour: 15, description: "a bite",           visionLabels: []) == .snack)
    }

    @Test func dinnerTimeBucket() {
        #expect(service.detect(hour: 19, description: "dinner time",      visionLabels: []) == .dinner)
    }

    @Test func lateNightFallback() {
        #expect(service.detect(hour: 2,  description: "crackers",         visionLabels: []) == .snack)
    }

    // MARK: - Case-insensitive matching

    @Test func caseInsensitiveBeverage() {
        #expect(service.detect(hour: 10, description: "COFFEE",           visionLabels: []) == .beverage)
    }

    @Test func caseInsensitiveDessert() {
        #expect(service.detect(hour: 14, description: "Chocolate Brownie", visionLabels: []) == .dessert)
    }

    @Test func caseInsensitiveBreakfast() {
        #expect(service.detect(hour: 19, description: "PANCAKE",          visionLabels: []) == .breakfast)
    }

    // MARK: - Beverage takes priority over dessert

    @Test func beveragePriorityOverDessert() {
        #expect(service.detect(hour: 15, description: "chocolate milk",   visionLabels: []) == .beverage)
    }

    // MARK: - Keyword overrides time (explicit confirmation tests)

    @Test func keywordOverridesTimeBucket_latteAt7pm() {
        // latte is a beverage keyword; 7pm would be .dinner by time bucket
        #expect(service.detect(hour: 19, description: "latte",            visionLabels: []) == .beverage)
    }

    @Test func keywordOverridesTimeBucket_steakAt8am() {
        // steak is a dinner keyword; 8am would be .breakfast by time bucket
        #expect(service.detect(hour: 8,  description: "steak",            visionLabels: []) == .dinner)
    }

    // MARK: - Indian / South Indian

    @Test func idliAtDinnerHour() {
        #expect(service.detect(hour: 20, description: "idli sambar",      visionLabels: []) == .breakfast)
    }

    @Test func dosaAtLunchHour() {
        #expect(service.detect(hour: 13, description: "masala dosa",      visionLabels: []) == .breakfast)
    }

    @Test func upmaAtNoon() {
        #expect(service.detect(hour: 12, description: "upma",             visionLabels: []) == .breakfast)
    }

    @Test func biryaniAtBreakfastHour() {
        #expect(service.detect(hour: 8,  description: "biryani",          visionLabels: []) == .lunch)
    }

    @Test func thaliAtBreakfastHour() {
        #expect(service.detect(hour: 9,  description: "thali",            visionLabels: []) == .lunch)
    }

    @Test func payasamAtNoon() {
        #expect(service.detect(hour: 12, description: "payasam",          visionLabels: []) == .dessert)
    }

    @Test func kheerAtLunchHour() {
        #expect(service.detect(hour: 13, description: "kheer",            visionLabels: []) == .dessert)
    }

    @Test func lassiAtDinnerHour() {
        #expect(service.detect(hour: 19, description: "lassi",            visionLabels: []) == .beverage)
    }

    @Test func chaasAtDinnerHour() {
        #expect(service.detect(hour: 20, description: "chaas",            visionLabels: []) == .beverage)
    }

    @Test func murukuAtBreakfastHour() {
        #expect(service.detect(hour: 9,  description: "murukku",          visionLabels: []) == .snack)
    }

    @Test func samosaAtLunchHour() {
        #expect(service.detect(hour: 13, description: "samosa",           visionLabels: []) == .snack)
    }

    @Test func tikkaAtBreakfastHour() {
        #expect(service.detect(hour: 9,  description: "chicken tikka",    visionLabels: []) == .dinner)
    }
}
