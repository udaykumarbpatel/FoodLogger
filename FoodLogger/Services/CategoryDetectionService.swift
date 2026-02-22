import Foundation

// Content-based keyword matching always takes priority over time-of-day buckets.
// If any keyword matches, the category is returned immediately.
// Time buckets are only consulted when zero keywords match.
@MainActor final class CategoryDetectionService {

    // MARK: - Keyword sets (O(1) lookup)

    private static let beverageKeywords: Set<String> = [
        "coffee", "tea", "juice", "water", "soda", "smoothie",
        "shake", "latte", "espresso", "milk", "beer", "wine", "drink",
        "cappuccino", "americano", "macchiato", "mocha", "frappe",
        "kombucha", "lemonade", "cocktail", "mocktail", "spirits",
        "whiskey", "vodka", "rum", "gin", "cider", "sparkling",
        "horchata", "matcha", "chai", "cocoa", "hot chocolate",
        // Indian beverages
        "lassi", "buttermilk", "chaas", "thandai", "jaljeera",
        "sharbat", "neera", "aam", "sol"
    ]

    private static let dessertKeywords: Set<String> = [
        "cake", "ice cream", "cookie", "brownie", "pie",
        "candy", "chocolate", "donut", "cupcake", "muffin",
        "pudding", "gelato", "sorbet", "tart", "pastry",
        "cheesecake", "tiramisu", "macaroon", "eclair", "fudge",
        "truffle", "sundae", "parfait", "cobbler", "mousse",
        // Indian sweets
        "kheer", "payasam", "halwa", "ladoo", "barfi", "jalebi",
        "rasgulla", "kulfi", "peda", "modak", "sheera", "kesari",
        "malpua", "shrikhand", "rabri", "gulab"
    ]

    private static let breakfastKeywords: Set<String> = [
        "oatmeal", "cereal", "granola", "pancake", "pancakes", "waffle", "waffles",
        "bagel", "muffin", "toast", "eggs", "bacon",
        "sausage", "yogurt", "porridge", "croissant", "brioche",
        "frittata", "omelette", "omelet", "hash", "grits",
        // Indian breakfast
        "idli", "dosa", "uttapam", "upma", "poha", "appam", "puttu",
        "idiyappam", "vada", "pongal", "pesarattu", "adai", "rava",
        "paratha", "dhokla"
    ]

    private static let lunchKeywords: Set<String> = [
        "sandwich", "wrap", "salad", "soup", "burger",
        "panini", "sub", "quesadilla", "taco", "burrito",
        "poke", "bowl", "noodle", "ramen", "udon",
        "falafel", "hummus", "pita", "club", "blt",
        // Indian lunch
        "biryani", "pulao", "thali", "rasam", "sambar", "kootu",
        "aviyal", "keerai", "poriyal", "rajma", "chole", "paneer",
        "khichdi", "chapati", "roti", "naan", "curd"
    ]

    private static let snackKeywords: Set<String> = [
        "chips", "crackers", "popcorn", "nuts", "pretzels",
        "granola bar", "trail mix", "fruit", "apple", "banana",
        "orange", "grapes", "berries", "celery", "carrot",
        "rice cake", "edamame", "jerky", "string cheese", "dates",
        // Indian snacks
        "murukku", "chakli", "chivda", "bhel", "thattai", "mixture",
        "bonda", "bhajji", "samosa", "pakoda", "pakora", "chaat"
    ]

    private static let dinnerKeywords: Set<String> = [
        "steak", "roast", "pasta", "pizza", "chicken",
        "salmon", "fish", "curry", "stew", "casserole",
        "risotto", "lasagna", "meatballs", "pork", "lamb",
        "beef", "shrimp", "scallops", "chops", "fillet",
        // Indian dinner
        "tandoori", "tikka", "kebab", "makhani", "korma"
    ]

    // MARK: - Detection

    func detect(hour: Int, description: String, visionLabels: [String]) -> MealCategory {
        let tokens = tokenize(description) + visionLabels.flatMap { tokenize($0) }

        // Content-first: keyword match wins immediately, no time bucket consulted
        if tokens.contains(where: { Self.beverageKeywords.contains($0) }) { return .beverage }
        if tokens.contains(where: { Self.dessertKeywords.contains($0) })  { return .dessert }
        if tokens.contains(where: { Self.breakfastKeywords.contains($0) }) { return .breakfast }
        if tokens.contains(where: { Self.lunchKeywords.contains($0) })    { return .lunch }
        if tokens.contains(where: { Self.snackKeywords.contains($0) })    { return .snack }
        if tokens.contains(where: { Self.dinnerKeywords.contains($0) })   { return .dinner }

        // Time-bucket fallback — only reached when zero content keywords match
        switch hour {
        case 5...10:  return .breakfast
        case 11...14: return .lunch
        case 15...16: return .snack
        case 17...20: return .dinner
        default:      return .snack
        }
    }

    // MARK: - Tokeniser

    private func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: ",")))
            .filter { !$0.isEmpty }
    }
}
