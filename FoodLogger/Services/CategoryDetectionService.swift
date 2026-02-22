import Foundation

@MainActor final class CategoryDetectionService {

    private static let beverageKeywords: Set<String> = [
        "coffee", "tea", "juice", "water", "soda", "smoothie",
        "shake", "latte", "espresso", "milk", "beer", "wine", "drink"
    ]

    private static let dessertKeywords: Set<String> = [
        "cake", "ice cream", "cookie", "brownie", "pie",
        "candy", "chocolate", "donut"
    ]

    func detect(hour: Int, description: String, visionLabels: [String]) -> MealCategory {
        let tokens = tokenize(description) + visionLabels.flatMap { tokenize($0) }

        if tokens.contains(where: { Self.beverageKeywords.contains($0) }) {
            return .beverage
        }

        if tokens.contains(where: { Self.dessertKeywords.contains($0) }) {
            return .dessert
        }

        switch hour {
        case 5...10:  return .breakfast
        case 11...14: return .lunch
        case 15...16: return .snack
        case 17...20: return .dinner
        default:      return .snack
        }
    }

    private func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: ",")))
            .filter { !$0.isEmpty }
    }
}
