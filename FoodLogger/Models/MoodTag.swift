import SwiftUI

enum MoodTag: String, Codable, CaseIterable {
    case energised    = "energised"
    case satisfied    = "satisfied"
    case neutral      = "neutral"
    case sluggish     = "sluggish"
    case uncomfortable = "uncomfortable"

    var emoji: String {
        switch self {
        case .energised:     return "\u{26A1}\u{FE0F}"
        case .satisfied:     return "\u{1F60C}"
        case .neutral:       return "\u{1F610}"
        case .sluggish:      return "\u{1F634}"
        case .uncomfortable: return "\u{1F623}"
        }
    }

    var label: String {
        switch self {
        case .energised:     return "Energised"
        case .satisfied:     return "Satisfied"
        case .neutral:       return "Neutral"
        case .sluggish:      return "Sluggish"
        case .uncomfortable: return "Uncomfortable"
        }
    }

    var color: Color {
        switch self {
        case .energised:     return Color(hex: "#2ECC71")
        case .satisfied:     return Color(hex: "#FF6B35")
        case .neutral:       return Color(hex: "#95A5A6")
        case .sluggish:      return Color(hex: "#FFB347")
        case .uncomfortable: return Color(hex: "#E74C3C")
        }
    }
}
