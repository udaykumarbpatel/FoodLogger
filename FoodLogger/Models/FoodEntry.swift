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
    var mediaURL: URL?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        rawInput: String,
        inputType: InputType,
        processedDescription: String,
        mediaURL: URL? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.rawInput = rawInput
        self.inputType = inputType
        self.processedDescription = processedDescription
        self.mediaURL = mediaURL
        self.createdAt = createdAt
    }
}
