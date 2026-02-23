import Foundation
import SwiftData

enum InputType: String, Codable, CaseIterable {
    case text
    case image
    case voice
}

@Model
final class FoodEntry {
    var id: UUID
    var date: Date
    var rawInput: String
    var inputType: InputType
    var processedDescription: String
    // Stores only the bare filename, e.g. URL(string: "uuid.jpg")! — never a file:// URL.
    // Always reconstruct the absolute path using .absoluteString, NOT .path:
    //   docsDir.appendingPathComponent(mediaURL.absoluteString)
    // Why: SwiftData may internally normalise a bare URL into a file:// URL. If that happens,
    // calling .path returns the full absolute path (e.g. "/var/mobile/.../Documents/uuid.jpg"),
    // and appendingPathComponent of that produces a doubled, broken path. .absoluteString always
    // returns the original string passed to URL(string:) — just the bare filename — making
    // reconstruction safe regardless of how SwiftData stores the value.
    var mediaURL: URL?
    var createdAt: Date
    var category: MealCategory?
    var updatedAt: Date?
    var mood: MoodTag?

    init(
        id: UUID = UUID(),
        date: Date,
        rawInput: String,
        inputType: InputType,
        processedDescription: String,
        mediaURL: URL? = nil,
        createdAt: Date = Date(),
        category: MealCategory? = nil,
        updatedAt: Date? = nil,
        mood: MoodTag? = nil
    ) {
        self.id = id
        self.date = date
        self.rawInput = rawInput
        self.inputType = inputType
        self.processedDescription = processedDescription
        self.mediaURL = mediaURL
        self.createdAt = createdAt
        self.category = category
        self.updatedAt = updatedAt
        self.mood = mood
    }
}
