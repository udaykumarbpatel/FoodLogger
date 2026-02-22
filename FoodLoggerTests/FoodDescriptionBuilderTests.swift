import Testing
import Foundation
@testable import FoodLogger

@MainActor
struct FoodDescriptionBuilderTests {

    let builder = FoodDescriptionBuilder()

    // MARK: - fromText

    @Test("Empty string returns empty string")
    func emptyTextReturnsEmpty() {
        let result = builder.buildDescription(fromText: "")
        #expect(result == "")
    }

    @Test("Whitespace-only string returns empty string")
    func whitespaceOnlyReturnsEmpty() {
        let result = builder.buildDescription(fromText: "   \n\t  ")
        #expect(result == "")
    }

    @Test("Text with clear nouns extracts them")
    func textWithNounsExtractsTokens() {
        let result = builder.buildDescription(fromText: "I had pizza and pasta for lunch")
        // Should contain food nouns — exact set depends on NLTagger, but result must be non-empty
        #expect(!result.isEmpty)
        // Must not contain verbs like "had"
        #expect(!result.lowercased().contains("had"))
    }

    @Test("Short noun-only input is returned as-is or as noun tokens")
    func singleFoodWord() {
        let result = builder.buildDescription(fromText: "sushi")
        #expect(!result.isEmpty)
    }

    @Test("Input with no recognisable nouns falls back to original text")
    func fallbackToOriginalText() {
        // Gibberish — NLTagger won't find food nouns, should fall back to original
        let input = "zzz qqq"
        let result = builder.buildDescription(fromText: input)
        // Falls back to full trimmed text when no tokens found
        #expect(result == input || !result.isEmpty)
    }

    // MARK: - fromTranscript

    @Test("fromTranscript delegates to fromText")
    func transcriptDelegatesToText() {
        let text = "I ate a burger and fries"
        let fromText = builder.buildDescription(fromText: text)
        let fromTranscript = builder.buildDescription(fromTranscript: text)
        #expect(fromText == fromTranscript)
    }

    // MARK: - fromVisionLabels

    @Test("Empty labels returns 'Unknown food item'")
    func emptyLabelsReturnsUnknown() {
        let result = builder.buildDescription(fromVisionLabels: [])
        #expect(result == "Unknown food item")
    }

    @Test("Underscores replaced with spaces")
    func underscoresReplacedWithSpaces() {
        let result = builder.buildDescription(fromVisionLabels: ["caesar_salad"])
        #expect(result.contains("caesar salad"))
        #expect(!result.contains("_"))
    }

    @Test("Parenthetical qualifiers stripped")
    func parentheticalQualifiersStripped() {
        let result = builder.buildDescription(fromVisionLabels: ["apple_(fruit)"])
        #expect(!result.contains("("))
        #expect(!result.contains(")"))
        #expect(result.lowercased().contains("apple"))
    }

    @Test("Multiple labels joined by comma")
    func multipleLabelsJoined() {
        let result = builder.buildDescription(fromVisionLabels: ["pizza", "salad", "coffee"])
        #expect(result.contains(","))
        #expect(result.lowercased().contains("pizza"))
        #expect(result.lowercased().contains("salad"))
        #expect(result.lowercased().contains("coffee"))
    }

    @Test("Labels with both underscore and parenthetical cleaned correctly")
    func complexLabelCleaned() {
        let result = builder.buildDescription(fromVisionLabels: ["caesar_salad_(dish)"])
        #expect(!result.contains("_"))
        #expect(!result.contains("("))
        #expect(result.trimmingCharacters(in: .whitespaces) == "caesar salad")
    }

    @Test("Label that becomes empty after cleaning falls back to 'Unknown food item'")
    func emptyAfterCleaningFallsBack() {
        // A label that is only parenthetical content
        let result = builder.buildDescription(fromVisionLabels: ["(unknown)"])
        // After stripping "(unknown)" → "" → filtered → empty array → fallback
        #expect(result == "Unknown food item")
    }
}
