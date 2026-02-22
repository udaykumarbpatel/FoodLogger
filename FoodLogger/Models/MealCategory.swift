import SwiftUI

enum MealCategory: String, Codable, CaseIterable {
    case breakfast
    case lunch
    case snack
    case dinner
    case dessert
    case beverage

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch:     return "Lunch"
        case .snack:     return "Snack"
        case .dinner:    return "Dinner"
        case .dessert:   return "Dessert"
        case .beverage:  return "Beverage"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch:     return "fork.knife"
        case .snack:     return "leaf"
        case .dinner:    return "moon.stars"
        case .dessert:   return "birthday.cake"
        case .beverage:  return "cup.and.saucer"
        }
    }

    var color: Color {
        switch self {
        case .breakfast: return .orange
        case .lunch:     return .green
        case .snack:     return .yellow
        case .dinner:    return .indigo
        case .dessert:   return .pink
        case .beverage:  return .teal
        }
    }
}
