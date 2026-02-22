import Testing
import Foundation
@testable import FoodLogger

@MainActor
struct ExportServiceTests {

    // MARK: - Helpers

    private func makeEntry(
        id: UUID = UUID(),
        date: Date = Date(),
        rawInput: String = "oatmeal",
        inputType: InputType = .text,
        processedDescription: String = "oatmeal with berries",
        category: MealCategory? = .breakfast,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) -> FoodEntry {
        FoodEntry(
            id: id,
            date: date,
            rawInput: rawInput,
            inputType: inputType,
            processedDescription: processedDescription,
            category: category,
            updatedAt: updatedAt
        )
    }

    private func parse(_ data: Data) throws -> [[String: Any]] {
        let obj = try JSONSerialization.jsonObject(with: data)
        guard let array = obj as? [[String: Any]] else {
            Issue.record("Expected JSON array of objects")
            return []
        }
        return array
    }

    // MARK: - Valid JSON

    @Test func producesValidJSON() throws {
        let entry = makeEntry()
        let data = try ExportService.jsonData(from: [entry])
        #expect(!data.isEmpty)
        _ = try JSONSerialization.jsonObject(with: data) // must not throw
    }

    // MARK: - All required fields present

    @Test func allRequiredFieldsPresent() throws {
        let entry = makeEntry()
        let data = try ExportService.jsonData(from: [entry])
        let array = try parse(data)
        #expect(array.count == 1)
        let obj = array[0]
        #expect(obj["id"] != nil)
        #expect(obj["date"] != nil)
        #expect(obj["rawInput"] != nil)
        #expect(obj["inputType"] != nil)
        #expect(obj["processedDescription"] != nil)
        #expect(obj["category"] != nil)
        #expect(obj["createdAt"] != nil)
        #expect(obj["updatedAt"] != nil)
    }

    // MARK: - Field values

    @Test func idFieldMatchesEntry() throws {
        let id = UUID()
        let entry = makeEntry(id: id)
        let data = try ExportService.jsonData(from: [entry])
        let obj = try parse(data)[0]
        #expect(obj["id"] as? String == id.uuidString)
    }

    @Test func inputTypeFieldIsRawValue() throws {
        let entry = makeEntry(inputType: .voice)
        let data = try ExportService.jsonData(from: [entry])
        let obj = try parse(data)[0]
        #expect(obj["inputType"] as? String == "voice")
    }

    @Test func categoryFieldIsRawValue() throws {
        let entry = makeEntry(category: .dinner)
        let data = try ExportService.jsonData(from: [entry])
        let obj = try parse(data)[0]
        #expect(obj["category"] as? String == "dinner")
    }

    @Test func nullCategorySerializesAsNSNull() throws {
        let entry = makeEntry(category: nil)
        let data = try ExportService.jsonData(from: [entry])
        let obj = try parse(data)[0]
        #expect(obj["category"] is NSNull)
    }

    @Test func nullUpdatedAtSerializesAsNSNull() throws {
        let entry = makeEntry(updatedAt: nil)
        let data = try ExportService.jsonData(from: [entry])
        let obj = try parse(data)[0]
        #expect(obj["updatedAt"] is NSNull)
    }

    @Test func updatedAtSerializesWhenPresent() throws {
        let now = Date()
        let entry = makeEntry(updatedAt: now)
        let data = try ExportService.jsonData(from: [entry])
        let obj = try parse(data)[0]
        let str = obj["updatedAt"] as? String
        #expect(str != nil)
        #expect(!(str?.isEmpty ?? true))
    }

    // MARK: - ISO8601 date format

    @Test func dateFieldIsISO8601() throws {
        let entry = makeEntry()
        let data = try ExportService.jsonData(from: [entry])
        let obj = try parse(data)[0]
        let dateStr = obj["date"] as? String ?? ""
        let formatter = ISO8601DateFormatter()
        #expect(formatter.date(from: dateStr) != nil)
    }

    @Test func createdAtFieldIsISO8601() throws {
        let entry = makeEntry()
        let data = try ExportService.jsonData(from: [entry])
        let obj = try parse(data)[0]
        let str = obj["createdAt"] as? String ?? ""
        let formatter = ISO8601DateFormatter()
        #expect(formatter.date(from: str) != nil)
    }

    @Test func updatedAtFieldIsISO8601WhenPresent() throws {
        let entry = makeEntry(updatedAt: Date())
        let data = try ExportService.jsonData(from: [entry])
        let obj = try parse(data)[0]
        let str = obj["updatedAt"] as? String ?? ""
        let formatter = ISO8601DateFormatter()
        #expect(formatter.date(from: str) != nil)
    }

    // MARK: - Empty array

    @Test func emptyEntriesProducesEmptyJSONArray() throws {
        let data = try ExportService.jsonData(from: [])
        let array = try parse(data)
        #expect(array.isEmpty)
    }

    // MARK: - Multiple entries

    @Test func multipleEntriesAllExported() throws {
        let entries = [makeEntry(), makeEntry(), makeEntry()]
        let data = try ExportService.jsonData(from: entries)
        let array = try parse(data)
        #expect(array.count == 3)
    }

    // MARK: - Filename format

    @Test func filenameFormatIsCorrect() {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2026
        components.month = 2
        components.day = 22
        let date = calendar.date(from: components)!
        let name = ExportService.filename(for: date)
        #expect(name == "foodlogger-export-2026-02-22.json")
    }

    @Test func filenameHasJSONExtension() {
        let name = ExportService.filename(for: Date())
        #expect(name.hasSuffix(".json"))
    }

    @Test func filenameStartsWithPrefix() {
        let name = ExportService.filename(for: Date())
        #expect(name.hasPrefix("foodlogger-export-"))
    }
}
