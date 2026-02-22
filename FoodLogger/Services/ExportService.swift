import Foundation

struct ExportService {

    // MARK: - Filename

    static func filename(for date: Date = Date()) -> String {
        let formatted = date.formatted(.iso8601
            .year().month().day()
            .dateSeparator(.dash))
        return "foodlogger-export-\(formatted).json"
    }

    // MARK: - Serialisation

    static func jsonData(from entries: [FoodEntry]) throws -> Data {
        let dicts = entries.map { entry -> [String: Any?] in
            [
                "id":                   entry.id.uuidString,
                "date":                 iso8601(entry.date),
                "rawInput":             entry.rawInput,
                "inputType":            entry.inputType.rawValue,
                "processedDescription": entry.processedDescription,
                "category":             entry.category?.rawValue,
                "createdAt":            iso8601(entry.createdAt),
                "updatedAt":            entry.updatedAt.map { iso8601($0) }
            ]
        }

        // JSONSerialization requires [String: Any], not [String: Any?]
        let sanitised = dicts.map { dict in
            dict.mapValues { value -> Any in
                if let v = value { return v }
                return NSNull()
            }
        }

        return try JSONSerialization.data(
            withJSONObject: sanitised,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    // MARK: - Helpers

    private static func iso8601(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
