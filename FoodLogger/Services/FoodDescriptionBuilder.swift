import Foundation
import NaturalLanguage

@MainActor
final class FoodDescriptionBuilder {

    func buildDescription(fromText text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var tokens: [String] = []
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = trimmed

        tagger.enumerateTags(
            in: trimmed.startIndex..<trimmed.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitPunctuation, .omitWhitespace]
        ) { tag, range in
            if let tag, tag == .noun || tag == .adjective {
                tokens.append(String(trimmed[range]))
            }
            return true
        }

        return tokens.isEmpty ? trimmed : tokens.joined(separator: ", ")
    }

    func buildDescription(fromTranscript transcript: String) -> String {
        buildDescription(fromText: transcript)
    }

    func buildDescription(fromVisionLabels labels: [String]) -> String {
        guard !labels.isEmpty else { return "Unknown food item" }

        let cleaned = labels.compactMap { label -> String? in
            let withSpaces = label.replacingOccurrences(of: "_", with: " ")
            let withoutParens = withSpaces.components(separatedBy: "(").first ?? withSpaces
            let result = withoutParens.trimmingCharacters(in: .whitespaces)
            return result.isEmpty ? nil : result
        }

        return cleaned.isEmpty ? "Unknown food item" : cleaned.joined(separator: ", ")
    }
}
